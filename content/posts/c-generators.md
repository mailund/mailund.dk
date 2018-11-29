---
title: "Generators in C"
date: 2018-11-23T14:02:40+01:00
categories: [Programming]
tags: [c, programming]
---

Now that I am almost done with [*The Joys of Hashing*](https://amzn.to/2pngZQ0), I am looking at the material I made last year for our [*Genome-scale Algorithms* class](https://kursuskatalog.au.dk/da/course/72431/Genome-Scale-Algorithms). I implemented a toy read mapper as an example for the final project. I wrote several different approaches to mapping, from generating all strings at a certain edit distance to a read and doing exact matching to branch-and-bound using BWT.

In the implementation, there were a few design decisions there that I was never quite happy with. I didn’t have time to fix them, though. We will teach the next class in the spring, and now I have a few weeks to improve the code.

One thing I particularly disliked with the implementation was the control-flow—several places I need to iterate through reads or matches or such. So, I have functions for that. To combine these iterations with my program, I used callbacks.

This approach is not a bad idea in some languages. If you have closures, it is a natural approach—you call an iteration algorithm with a closure that does what it does in the scope where you use the iterator.

Unfortunately, I used C, and there are no closures there. That makes it very hard to follow what the program does. So, instead, I wanted something similar to Python’s generators. There, you can write a function that iterates over a sequence of objects and returns control-flow to the caller for each of them, and when called again, continues with the iteration.

You cannot do this directly in C, but you can wrap the iteration state in a `struct` and use that. It is not unlike how `FILE` pointers are used to work with streams.

I rewrote a couple of functions today to experiment with it.

### Reading FASTQ files

A simple example is iterating through reads in a FASTQ file. In my implementation from last year, I defined a callback that is called with each read and a function that iterates through a FASTQ file. The interface looks like this:

```c
typedef void (*fastq_read_callback_func)(
    const char *read_name,
    const char *read,
    const char *quality,
    void * callback_data
);

void scan_fastq(
    FILE *file,
    fastq_read_callback_func
    callback,
    void * callback_data
);
```

I implemented the function like this:

```c
void scan_fastq(
    FILE *file,
    fastq_read_callback_func callback,
     void * callback_data
) {
    char buffer[MAX_LINE_SIZE];

    while (fgets(buffer, MAX_LINE_SIZE, file) != 0) {
        char *name = strtok(buffer+1, "\n");
        fgets(buffer, MAX_LINE_SIZE, file);
        char *seq = strtok(buffer, "\n");
        fgets(buffer, MAX_LINE_SIZE, file);
        fgets(buffer, MAX_LINE_SIZE, file);
        char *qual = strtok(buffer, "\n");

        callback(name, seq, qual, callback_data);

        free(name);
        free(seq);
        free(qual);
    }
}
```

To get a generator instead, I need to wrap the iteration state, and I need a structure to return reads. 

```c
struct fastq_iter {
    FILE *file;
    char *buffer;
};
struct fastq_record {
    const char *name;
    const char *sequence;
    const char *quality;
};
```

I could make the second struct an opaque structure by putting it in the .c file and work with pointers to it in the interface, but so far I have put it in the header so I can allocate iterators on the stack. I expose the structure, but you are not supposed to mess with it—if you do, you will get punished if I change it. So, I might change that design.

As it stands right now, I have a function that initialises the iterator and one that frees resources from it. They both take the iterator as a parameter.

```c
void fastq_init_iter(
    struct fastq_iter *iter,
    FILE *file
);
void fastq_dealloc_iter(
    struct fastq_iter *iter
);
```

I put the file-stream in the iterator and allocate a buffer for it. Since the file object can be any stream, I do not want to allocate it for the iterator, so I do not touch it when I free iterator resources either. But, of courses, I do need to free the buffer.

```c
void fastq_init_iter(
    struct fastq_iter *iter,
    FILE *file
) {
    iter->file = file;
    iter->buffer = malloc(MAX_LINE_SIZE);
}

void fastq_dealloc_iter(
    struct fastq_iter *iter
) {
    free(iter->buffer);
}
```

To iterate over reads, I use this function:

```c
bool fastq_next_record(
    struct fastq_iter *iter,
    struct fastq_record *record
) {
    FILE *file = iter->file;
    char *buffer = iter->buffer;
    if (fgets(buffer, MAX_LINE_SIZE, file)) {
        record->name = string_copy(strtok(buffer+1, "\n"));
        fgets(buffer, MAX_LINE_SIZE, file);
        record->sequence = string_copy(strtok(buffer, "\n"));
        fgets(buffer, MAX_LINE_SIZE, file);
        fgets(buffer, MAX_LINE_SIZE, file);
        record->quality = string_copy(strtok(buffer, "\n"));
        return true;
    }
    return false;
}
```

It does the same as the callback function but it uses the iterator for all the state, and it returns `true` when it generates an object—and puts it in the `record` structure. When there are no more objects, it returns `false`.

A simple program that iterates through a file of reads and prints them out again—a specialised `cat` if you will, can look like this:

```c
#include <stdlib.h>
#include <stdio.h>
#include <fastq.h>

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("needs one argument\n");
        return EXIT_FAILURE;
    }

    FILE *input = fopen(argv[1], "r");
    struct fastq_iter iter;
    struct fastq_record record;
    fastq_init_iter(&iter, input);
    while (fastq_next_record(&iter, &record)) {
        printf("@%s\n", record.name);
        printf("%s\n", record.sequence);
        printf("+\n");
        printf("%s\n", record.quality);
    }
    fastq_dealloc_iter(&iter);
    fclose(input);

    return EXIT_SUCCESS;
}
```

### Exact pattern matching

Another example of iteration is pattern matching, i.e. finding all occurrences of one string, `pattern`, in another, `text`. I have implemented different algorithms for this. Below I have listed a naive algorithm—one that tries to match the pattern at each index in the text—and the [Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm). The callback versions have the same interface.

```c
typedef void (*match_callback_func)(
    size_t index, 
    void * data
);

void naive_exact_match(
    const char *text, size_t n,
    const char *pattern, size_t m,
    match_callback_func callback, 
    void *callback_data
);
void knuth_morris_pratt(
    const char *text, size_t n,
    const char *pattern, size_t m,
    match_callback_func callback, 
    void *callback_data
);
```

The state in the iterations differs, though. The naive algorithm only needs to know the index in the text we have reached to match a pattern:

```c
void naive_exact_match(
    const char *text, size_t n,
    const char *pattern, size_t m,
    match_callback_func callback,
    void *callback_data
) {
    if (m > n) {
        // This is necessary because n and m are unsigned so the
        // "j < n - m + 1" loop test can suffer from an overflow.
        return;
    }

    for (size_t j = 0; j <= n - m; j++) {
        size_t i = 0;
        while (i < m && text[j+i] == pattern[i]) {
            i++;
        }
        if (i == m) {
            callback(j, callback_data);
        }
    }
}
```

The KMP algorithm also needs a border array.

```c
void knuth_morris_pratt(    
    const char *text, size_t n,
    const char *pattern, size_t m,
    match_callback_func callback,
    void *callback_data
) {
    if (m > n) {
        // This is necessary because n and m are unsigned so the
        // "j < n - m + 1" loop test can suffer from an overflow.
        return;
    }

    // preprocessing
    size_t prefixtab[m];
    prefixtab[0] = 0;
    for (size_t i = 1; i < m; ++i) {
        size_t k = prefixtab[i-1];
        while (k > 0 && pattern[i] != pattern[k])
            k = prefixtab[k-1];
        prefixtab[i] = (pattern[i] == pattern[k]) ? k + 1 : 0;
    }

    // matching
    size_t j = 0, q = 0;
    size_t max_match_len = n - m + 1; // same as for the naive algorithm
    // here we compensate for j pointing q into match
    while (j < max_match_len + q) {
        while (q < m && text[j] == pattern[q]) {
            q++; j++;
        }
        if (q == m) {
            callback(j - m, callback_data);
        }
        if (q == 0) {
            j++;
        } else {
            q = prefixtab[q-1];
        }
    }
}
```

The generator functions need a structure for returning each match. I could use an integer here, but for consistency, I have used a struct.

```c
struct match {
    size_t pos;
};
```

The interface to the two algorithms is the same but since I need more state in the KMP algorithm, the iterator structures differ, so I cannot use the same functions. So, I have these functions for the naive algorithm:

```c
struct match_naive_iter {
    const char *text;    size_t n;
    const char *pattern; size_t m;
    size_t current_index;
};
void match_init_naive_iter(
    struct match_naive_iter *iter,
    const char *text, size_t n,
    const char *pattern, size_t m
);
bool next_naive_match(
    struct match_naive_iter *iter,
    struct match *match
);
void match_dealloc_naive_iter(
    struct match_naive_iter *iter
);
```

And I have these functions for KMP.

```c
struct match_kmp_iter {
    const char *text;    size_t n;
    const char *pattern; size_t m;
    size_t *prefixtab;
    size_t max_match_len;
    size_t j, q;
};
void match_init_kmp_iter(
    struct match_kmp_iter *iter,
    const char *text, size_t n,
    const char *pattern, size_t m
);
bool next_kmp_match(
    struct match_kmp_iter *iter,
    struct match *match
);
void match_dealloc_kmp_iter(
    struct match_kmp_iter *iter
);
```

I do the sanity test in the iterator initialisation instead of the generators:

```c
void match_init_naive_iter(
    struct match_naive_iter *iter,
    const char *text, size_t n,
    const char *pattern, size_t m
) {
    // This is necessary because n and m are unsigned so the
    // "j < n - m + 1" loop test can suffer from an overflow.
    assert(m <= n);

    iter->text = text;       iter->n = n;
    iter->pattern = pattern; iter->m = m;
    iter->current_index = 0;
}

void match_init_kmp_iter(
    struct match_kmp_iter *iter,
    const char *text, size_t n,
    const char *pattern, size_t m
) {
    // This is necessary because n and m are unsigned so the
    // "j < n - m + 1" loop test can suffer from an overflow.
    assert(m <= n);

    iter->text = text;       iter->n = n;
    iter->pattern = pattern; iter->m = m;
    iter->j = 0;             iter->q = 0;
    iter->max_match_len = n - m + 1;

    iter->prefixtab = malloc(m);
    iter->prefixtab[0] = 0;
    for (size_t i = 1; i < m; ++i) {
        size_t k = iter->prefixtab[i-1];
        while (k > 0 && pattern[i] != pattern[k])
            k = iter->prefixtab[k-1];
        iter->prefixtab[i] = (pattern[i] == pattern[k]) ? k + 1 : 0;
    }
}
```

In the KMP iterator initialisation, I build the border array as well.

The function for freeing resources for the naive algorithm does do anything, but I have it for consistency (and in case I need to free something at a later time).

```c
void match_dealloc_naive_iter(
    struct match_naive_iter *iter
) {
    // nothing to do here...
}
```

For the KMP deallocator, I need to free the border array.

```c
void match_dealloc_kmp_iter(
    struct match_kmp_iter *iter
) {
    free(iter->prefixtab);
}
```

With the iterator states, the generators look precisely like the callback versions.

```c
bool next_naive_match(
    struct match_naive_iter *iter,
    struct match *match
) {
    size_t n = iter->n, m = iter->m;
    const char *text = iter->text;
    const char *pattern = iter->pattern;

    for (size_t j = iter->current_index; j <= n - m; j++) {
        size_t i = 0;
        while (i < m && text[j+i] == pattern[i]) {
            i++;
        }
        if (i == m) {
            //callback(j, callback_data);
            iter->current_index = j + 1;
            match->pos = j;
            return true;
        }
    }

    return false;
}

bool next_kmp_match(
    struct match_kmp_iter *iter,
    struct match *match
) {
    // aliases to make the code easier to read... but
    // remember to update the actual integers before
    // yielding to the caller...
    size_t j = iter->j;
    size_t q = iter->q;
    size_t m = iter->m;
    size_t max_match_index = iter->max_match_len;
    const char *text = iter->text;
    const char *pattern = iter->pattern;

    // here we compensate for j pointing q into match
    while (j < max_match_index + q) {
        while (q < m && text[j] == pattern[q]) {
            q++; j++;
        }
        if (q == m) {
            // yield
            if (q == 0) j++;
            else q = iter->prefixtab[q-1];
            iter->j = j; iter->q = q;
            match->pos = j - m;
            return true;
        }
        if (q == 0) {
            j++;
        } else {
            q = iter->prefixtab[q-1];
        }
    }
    return false;
}

```

### Handling recursion

To do approximate matching, I wrote a function that generates all strings at a maximum distance from a pattern. I know that this is a very inefficient approach to approximative matching, but I used it for pedagogical reasons.

```c
typedef void (*edits_callback_func)(
    const char *string,
    const char *cigar,
    void * data
);

void generate_all_neighbours(
    const char *pattern,
    const char *alphabet,
    int max_edit_distance,
    edits_callback_func callback,
    void *callback_data
);
```

A natural way to implement the function is using recursion, and I already added a bit of state for that. I do not update most of it, however. I use it mainly to store pointers to buffers I use to generate patterns and CIGAR-strings for the edits. I modify the buffers in the recursion, and the structure keeps the beginning of the buffers so I can use them when reporting a string.

The code listing below is a bit long, but it is simple enough. I try all edits in the recursion and report a string whenever I reach the base cases of the recursion.

```c
struct recursive_constant_data {
    const char *buffer_front;
    const char *cigar_front;
    const char *alphabet;
    char *simplify_cigar_buffer;
};
void generate_all_neighbours(
    const char *pattern,
    const char *alphabet,
    int max_edit_distance,
    edits_callback_func callback,
    void *callback_data
) {
    size_t n = strlen(pattern) + max_edit_distance + 1;
    char buffer[n];
    char cigar[n], cigar_buffer[n];
    struct recursive_constant_data data = { 
        buffer, cigar, alphabet, cigar_buffer 
    };
    recursive_generator(
        pattern, 
        buffer, 
        cigar, 
        max_edit_distance, 
        &data,
        callback, 
        callback_data
    );
}

static void recursive_generator(
    const char *pattern, char *buffer, char *cigar,
    int max_edit_distance,
    struct recursive_constant_data *data,
    edits_callback_func callback,
    void *callback_data
) {
    if (*pattern == '\0') {
        // no more pattern to match ... terminate the buffer and call back
        *buffer = '\0';
        *cigar = '\0';
        simplify_cigar(data->cigar_front, data->simplify_cigar_buffer);
        callback(data->buffer_front, data->simplify_cigar_buffer, callback_data);

    } else if (max_edit_distance == 0) {
        // we can't edit any more, so just move pattern to buffer and call back
        size_t rest = strlen(pattern);
        for (size_t i = 0; i < rest; ++i) {
            buffer[i] = pattern[i];
            cigar[i] = 'M';
        }
        buffer[rest] = cigar[rest] = '\0';
        simplify_cigar(data->cigar_front, data->simplify_cigar_buffer);
        callback(data->buffer_front, data->simplify_cigar_buffer, callback_data);

    } else {
        // --- time to recurse --------------------------------------
        // deletion
        *cigar = 'I';
        recursive_generator(pattern + 1, buffer, cigar + 1,
                            max_edit_distance - 1, data,
                            callback, callback_data);
        // insertion
        for (const char *a = data->alphabet; *a; a++) {
            *buffer = *a;
            *cigar = 'D';
            recursive_generator(pattern, buffer + 1, cigar + 1,
                                max_edit_distance - 1, data,
                                callback, callback_data);
        }
        // match / substitution
        for (const char *a = data->alphabet; *a; a++) {
            if (*a == *pattern) {
                *buffer = *a;
                *cigar = 'M';
                recursive_generator(pattern + 1, buffer + 1, cigar + 1,
                                    max_edit_distance, data,
                                    callback, callback_data);
            } else {
                *buffer = *a;
                *cigar = 'M';
                recursive_generator(pattern + 1, buffer + 1, cigar + 1,
                                    max_edit_distance - 1, data,
                                    callback, callback_data);
            }
        }
    }
}
```

In the recursion, what I do is this: I create a pattern for all the edits, and then I construct a string that contains all the edits operations. For example, two deletions and two matches will give me the edit string `DDMM`. Yes, it looks strange that two insertions are recorded at two deletions, but this is because the operations are relative to the `text` string and not the `pattern`, so insertions and deletions are switched.

What the `simplify_cigar` function does is translating the string with the individual edit operations into a CIGAR string. Maybe the name isn’t that well chosen, but that is what I called it. A better name could be `edits_to_cigar` or something like that. Anyway, in a CIGAR string, two deletions and two matches are recorded as `2D2M`. The function does that translation.

```c
void simplify_cigar(const char *cigar, char *buffer)
{
    while (*cigar) {
        const char *next = scan(cigar);
        buffer = buffer + sprintf(buffer, "%lu%c", next - cigar, *cigar);
        cigar = next;
    }
    *buffer = '\0';
}
```

To handle recursion in an iterator, I need an explicit stack. I use a stack frame structure for this.

```c
struct edit_iter_frame;
struct edit_iter {
    const char *pattern;
    const char *alphabet;

    char *buffer;
    char *cigar;
    char *simplify_cigar_buffer;

    struct edit_iter_frame *frames;
};
struct edit_pattern {
    const char *pattern;
    const char *cigar;
};

void edit_init_iter(
    struct edit_iter *iter,
    const char *pattern,
    const char *alphabet,
    int max_edit_distance
);
bool edit_next_pattern(
    struct edit_iter *iter,
    struct edit_pattern *result
);
void edit_dealloc_iter(
    struct edit_iter *iter
);
```

Where it gets a little complicated is that I need several recursions when in the edit cases. If I had persistent frame data—that is, if I never modified data that would give me side effects—I could push frames to the stack. Unfortunately, that is not the case here. I modify the buffers in the recursions, so the frames I push onto the stack are modified between the push and the pop.

Because of this, I need to modify the buffers just before I recurse; I cannot push a frame to the stack and handle the frames one a time.

I am not sure this is the most elegant way to handle it, but what I did was this: I split the recursions into two steps. The first generates the recursive calls, and the second modifies the buffers and push a frame to the stack for running the first step recursively.

I defined opcodes for the different operations and structures for storing the state of the operations like this:

```c
enum edit_op {
    EXECUTE,
    DELETION,
    INSERTION,
    MATCH
};
struct deletion_info {
    // No extra info
};
struct insertion_info {
    char a;
};
struct match_info {
    char a;
};
```

The `EXECUTE` operation pushes the different edits to the stack; the other operations modify the state and push the `EXECUTE` operation for the recursions onto the stack.

The stack frames contain the opcodes, the data associated with them, and the program state I need for each frame:

```c
struct edit_iter_frame {
    enum edit_op op;
    union {
        struct deletion_info  d;
        struct insertion_info i;
        struct match_info     m;
    } op_data;

    const char *pattern_front;
    char *buffer_front;
    char *cigar_front;
    int max_dist;
    struct edit_iter_frame *next;
};
```

I wrote a function for pushing stack frames. It doesn’t set the entire state for the frames—I would need separate functions for each operation if I want to add the operation data with the frame. Instead, I will update the frame after I have pushed it. Maybe not that pretty, but that is where I am right now.

```c
static struct edit_iter_frame *
push_edit_iter_frame(
    enum edit_op op,
    const char *pattern_front,
    char *buffer_front,
    char *cigar_front,
    int max_dist,
    struct edit_iter_frame *next
) {
    struct edit_iter_frame *frame =
        malloc(sizeof(struct edit_iter_frame));
    frame->op = op;
    frame->pattern_front = pattern_front;
    frame->buffer_front = buffer_front;
    frame->cigar_front = cigar_front,
    frame->max_dist = max_dist;
    frame->next = next;
    return frame;
}
```

When I initialise the iterator, I push an `EXECUTE` frame to the stack. It will push the first operation-recursions onto the stack when I start the generator.

```c
void edit_init_iter(
    struct edit_iter *iter,
    const char *pattern,
    const char *alphabet,
    int max_edit_distance
) {
    size_t n = strlen(pattern) + max_edit_distance + 1;

    iter->pattern = pattern;
    iter->alphabet = alphabet;

    iter->buffer = malloc(n); iter->buffer[n - 1] = '\0';
    iter->cigar = malloc(n);  iter->cigar[n - 1] = '\0';
    iter->simplify_cigar_buffer = malloc(n);

    iter->frames = push_edit_iter_frame(
        EXECUTE,
        iter->pattern,
        iter->buffer,
        iter->cigar,
        max_edit_distance,
        0
    );
}
```

When I deallocate an iterator, I free the buffers.

```c
void edit_dealloc_iter(struct edit_iter *iter)
{
    free(iter->buffer);
    free(iter->cigar);
    free(iter->simplify_cigar_buffer);
}
```

Now, for the generator, I report that I am finished when there are no more stack frames. Otherwise, I check if I have reached a base case in the recursion and if so, I report a string. Otherwise, I figure out which operation I need to do in a `switch`. An `EXECUTE` operation means that I need to push the different recursion frames to the stack. The other operations mean I need to update the buffers and then push an `EXECUTE` operation to execute the operation.

```c

bool edit_next_pattern(
    struct edit_iter *iter,
    struct edit_pattern *result
) {
    assert(iter);
    assert(result);

    if (iter->frames == 0) return false;

    // pop top frame
    struct edit_iter_frame *frame = iter->frames;
    iter->frames = frame->next;

    const char *pattern = frame->pattern_front;
    char *buffer = frame->buffer_front;
    char *cigar = frame->cigar_front;

    if (*pattern == '\0') {
        // no more pattern to match ... terminate the buffer and call back
        *buffer = '\0';
        *cigar = '\0';
        simplify_cigar(iter->cigar, iter->simplify_cigar_buffer);
        result->pattern = iter->buffer;
        result->cigar = iter->simplify_cigar_buffer;
        free(frame);
        return true;

    } else if (frame->max_dist == 0) {
        // we can't edit any more, so just move pattern to buffer and call back
        size_t rest = strlen(pattern);
        for (size_t i = 0; i < rest; ++i) {
              buffer[i] = pattern[i];
              cigar[i] = 'M';
        }
        buffer[rest] = cigar[rest] = '\0';
        simplify_cigar(iter->cigar, iter->simplify_cigar_buffer);
        result->pattern = iter->buffer;
        result->cigar = iter->simplify_cigar_buffer;
        free(frame);
        return true;
    }

    switch (frame->op) {
        case EXECUTE:
            for (const char *a = iter->alphabet; *a; a++) {
                iter->frames = push_edit_iter_frame(
                    INSERTION,
                    frame->pattern_front,
                    frame->buffer_front,
                    frame->cigar_front,
                    frame->max_dist,
                    iter->frames
                );
                iter->frames->op_data.i.a = *a;
                iter->frames = push_edit_iter_frame(
                    MATCH,
                    frame->pattern_front,
                    frame->buffer_front,
                    frame->cigar_front,
                    frame->max_dist,
                    iter->frames
                );
                iter->frames->op_data.m.a = *a;
            }
            iter->frames = push_edit_iter_frame(
                DELETION,
                frame->pattern_front,
                frame->buffer_front,
                frame->cigar_front,
                frame->max_dist,
                iter->frames
            );
            break;

        case DELETION:
            *cigar = 'I';
            iter->frames = push_edit_iter_frame(
                EXECUTE,
                frame->pattern_front + 1,
                frame->buffer_front,
                frame->cigar_front + 1,
                frame->max_dist - 1,
                iter->frames
            );
            break;

        case INSERTION:
            *buffer = frame->op_data.i.a;
            *cigar = 'D';
            iter->frames = push_edit_iter_frame(
                EXECUTE,
                frame->pattern_front,
                frame->buffer_front + 1,
                frame->cigar_front + 1,
                frame->max_dist - 1,
                iter->frames
            );

            break;
        case MATCH:
            if (frame->op_data.m.a == *pattern) {
                *buffer = frame->op_data.m.a;
                *cigar = 'M';
                iter->frames = push_edit_iter_frame(
                    EXECUTE,
                    frame->pattern_front + 1,
                    frame->buffer_front + 1,
                    frame->cigar_front + 1,
                    frame->max_dist,
                    iter->frames
                );
            } else {
                *buffer = frame->op_data.m.a;
                *cigar = 'M';
                iter->frames = push_edit_iter_frame(
                    EXECUTE,
                    frame->pattern_front + 1,
                    frame->buffer_front + 1,
                    frame->cigar_front + 1,
                    frame->max_dist - 1,
                    iter->frames
                );
            }
            break;

        default:
            assert(false);
    }

    free(frame);
    return edit_next_pattern(iter, result);
}
```

I have a lot more callback functions to update, but this is how I have gotten this far. What do you think? Do you have suggestions for smarter ways to do this? How do you implement generators in C? I would love to hear from you if you have ideas or experience with this.

<hr/>
<small>If you liked what you read, and want more like it, consider supporting me at [Patreon](https://www.patreon.com/mailund).</small>
<hr/>
