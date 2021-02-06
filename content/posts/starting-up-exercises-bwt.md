---
title: "Starting Up Exercises: Burrows-Wheeler Transform"
date: 2021-02-05T10:19:43+01:00
categories: ["Programming"]
tags: [programming, go, C, python, "string algorithms", teaching]
---

I am supervising some projects this spring, on algorithms for read-mapping. It's different projects that all involve implementing a working, but primitive, read mapper.

There is nothing new there, I have a class every year where we do that, but now it is individual projects. The content doesn't change much; just the teaching format.

They are free to implement the algorithms in any language they like, and in my class, they usually chose Python, and on occasion C. That makes it easy for me because I am fluent in those languages.

But this time, the groups are from the computer science department, and that isn't good enough for them, oh no. They want to use Go—which I'm okay with because I have played with it enough to see how that would work—and Rust—which might be a problem for me.

I had planned to learn both languages in spring anyway, so I guess it adds extra motivation.

An excellent way to get started on the project is to build a [suffix array](https://en.wikipedia.org/wiki/Suffix_array) and the [Burrows-Wheeler transform](https://en.wikipedia.org/wiki/Burrows–Wheeler_transform) as naïvely as you can.

The suffix array is an array of indices into the string, such that if you go through them in order, you get the suffixes in lexicographical order. So think about it as an efficient representation of all the sorted suffixes. Suffixes are just represented by their index into the string.

## C implementation

The simplest I can think of for constructing it, with my limited abilities, is to use C's builtin `qsort()` function. Build an array of all the suffixes of a string and sort them. Building the array is cheap because you just collect pointers into the string you build the array over. Sorting is expensive, though. Comparing two suffixes take time \\( O(n) \\) and you need to make \\( O(n \log n) \\) comparisons, so you end up with \\( O(n^2\log n) \\).

In practice, it is not that bad, though. Comparisons do not take linear time unless you are in a worst-case situation where you have a string of identical characters. If you have a random string, you spend constant time (that depends on the alphabet size, though, but not the string length). So it is close to \\( O(n\log n) \\) in practise.  Not as good as the linear time construction algorithms, of course, but those come later. The simplest approach is a good place to start, and it looks like this:

```c
static // Wrapper of strcmp needed for qsort
int construction_cmpfunc(void const * a, void const * b)
{
    return strcmp(*(char **)a, *(char **)b);
}

int *suffix_array(char const * x, size_t n)
{
    char const ** suffixes = malloc(n * sizeof *suffixes);
    if (!suffixes) return 0;

    // Sort the suffixes...
    for (size_t i = 0; i < n; i++) {
        suffixes[i] = x + i;
    }
    qsort(suffixes, n, sizeof(char *), construction_cmpfunc);

    // Build the suffix array from sorted suffixes
    int *sa = malloc(n * sizeof *sa);
    if (sa) {
        for (size_t i = 0; i < n; i++) {
            sa[i] = suffixes[i] - x;
        }
    }

    free(suffixes);
    return sa;
}
```

For the Burrows-Wheeler Transform, BWT, think of the suffixes but as rotations. All the suffixes of "foobar" are

```
foobar
 oobar
  obar
   bar
    ar
     r
```

But we typically append a "sentinel" character to the string, smaller than all others. It helps simplify a *lot* of algorithms by ensuring that no suffix is a prefix of another suffix, so we would write instead:

```
foobar$
 oobar$
  obar$
   bar$
    ar$
     r$
      $
```

Those are the suffixes we sort when we build the suffix array.

But, as I said, for the BWT, you want to think about *rotations* instead. Whatever we remove from the beginning of the string to get a suffix, we append to the end.

```
foobar$
oobar$f
obar$fo
bar$foo
ar$foob
r$fooba
$foobar
```

Sort them, as we did with the suffix array, and you get the *BWT matrix*.

```
$foobar
ar$foob
bar$foo
foobar$
oobar$f
obar$fo
r$fooba
```

It is just all the rotations, sorted.

The *Burrows-Wheeler transform* is the last column in the matrix. It has various properties that make it suitable for compression and efficient searching.

If you have the suffix array, you get the BWT almost for free. Well, in linear time, but free enough.

The BWT is the last column in the BWT matrix. The character in the first column is the index where a suffix starts, and since the rotations are sorted, at row \\(i\\), you have the suffix of rank \\(i\\). So to get the first character in row \\(i\\), you find out which suffix has rank \\(i\\), and the suffix array gives you that: `sa[i]`. You don't want that character, for the BWT, but the one that came before it. The one that came before it is the last column's character because the rows are rotations.

So to get the last column, run through the rows, get the index of the rank \\(i\\) suffix, `sa[i]`, and get the character before that index, `x[sa[i]-1]`.

There is a special case when the `sa[i]` is the first suffix, of course, because you cannot look to the left of that, but in that case, it is the last character in the string, which is always the sentinel.

In C, we can compute the BWT like this:

```c
char *bwt(char const * x, int *sa, size_t n)
{
    char *bwt = malloc(n * sizeof *bwt);
    if (bwt) {
        for (size_t i = 0; i < n; i++) {
            bwt[i] = (sa[i] == 0) ? '\0' : x[sa[i] - 1];
        }
    }
    return bwt;
}
```

I'm using the zero-character for sentinel because we want one that is smaller than all other letters (and because it is already used as a sentinel in C). In the literature, you always use $, but the zero-character is a better choice in an implementation.

We can use the two functions like this:

```C
int main(void)
{
    char *x = "foobar";
    size_t n = strlen(x) + 1;
    int *sa = suffix_array(x, n);
    if (!sa) perror("Couldn't allocate suffix array.");

    for (size_t i = 0; i < n; i++) {
        printf("%d %s\n", sa[i], x + sa[i]);
    }

    char *b = bwt(x, sa, n);
    if (!b) perror("Couldn't construct BWT.");

    for (size_t i = 0; i < n; i++) {
        putchar((b[i] == 0) ? '$' : b[i]);
    }
    putchar('\n');

    free(sa);
    free(b);
    return 0;
}
```

For the output, I translate the zero byte into the dollar-sign to see it in the terminal.

## Python implementation

For Python, where getting sub-strings means slicing, which means copying, building the same kind of array of suffixes is inefficient. Of course, you can use your own comparison algorithm for comparing substrings using indices, but it is just as easy to implement another approach. Take all the strings, and radix sort them:

```python
import itertools

def suffix_bucket(x, i, offset):
    idx = i + offset
    return x[idx] if idx < len(x) else 0

def bucket_sort(x, suffixes, offset, alphabet):
    buckets = [[] for _ in alphabet]
    for i in suffixes:
        buckets[suffix_bucket(x, i, offset)].append(i)
    return itertools.chain(*buckets)

def suffix_array(x):
    """Computes the suffix array with a radix sort"""
    alphabet = set(x)
    symbol_map = dict(
        (symb,i) for i,symb in enumerate(sorted(alphabet))
    )
    suffixes = range(len(x))
    mapped_x = [symbol_map[symb] for symb in x]
    for offset in range(len(x) - 1, -1, -1):
        suffixes = bucket_sort(mapped_x, suffixes, offset, alphabet)
    return list(suffixes)
```

There is a little more code, but it isn't horrible.

The complexity is \\( O(n^2) \\) so better than the worst-case for the C solution, but worse than the expected case for the comparison based sorting approach.

BWT in Python can be written succinctly like this:

```python
def bwt(x, sa):
    return ''.join(
        "\x00" if (sa[i] == 0) else x[sa[i] - 1]
        for i in range(len(x))
    )
```

This, then, is how you would use the functions in Python:

```python
x = "foobar\x00"
sa = suffix_array(x)
for i in sa:
    print(i, x[i:])

b = bwt(x, sa).replace("\x00", "$")
print(b)
```

I explicitly add the zero-byte as a sentinel to the string because Python strings are not zero-terminated the way that C strings are.

## Go implementation

I am only half-way into my Go book, so I don't know if this is horrible or the way to do it in that language, but constructing the suffix array certainly can be done in a similar way as with C:

```go
func SuffixArray(x string) []int {
	sa := make([]int, len(x))
	for i := 0; i < len(x); i++ {
		sa[i] = i
	}
	sort.Slice(sa, func(i, j int) bool {
		return x[sa[i]:] < x[sa[j]:]
	})
	return sa
}
```

As I understand it, the slicing is constant time, so the comparison function only spends the time it takes to compare the two strings, and no extra time on copying, which is what I needed to avoid with the radix sort in Python.

I am not sure if this is the right way to construct a string in Go:

```go
func BWT(x string, sa []int) string {
	bwt := make([]byte, len(x)) // FIXME: is this the proper type?
	for i := 0; i < len(x); i++ {
		if sa[i] == 0 {
			bwt[i] = '\x00'
		} else {
			bwt[i] = x[sa[i]-1]
		}
	}
	return string(bwt)
}
```

I am making a byte slice and creating the BWT string in that, and then casting it at the end. Strings are immutable in Go, and this is how I figured you are supposed to do it. But someone with Go experience, please let me know!

You can use the functions like this:

```go
func main() {
	x := "foobar\x00"
	sa := SuffixArray(x)
	for i := 0; i < len(x); i++ {
		fmt.Println(sa[i], x[sa[i]:])
	}
	bwt := BWT(x, sa)
	bwt = strings.Replace(bwt, "\x00", "$", 1)
	fmt.Println(bwt)
}
```

## Rust?

And then I got to Rust and hit a wall right away. I don't know the language, so of course, I would hit a wall, but it was rather quickly.

I don't know how to even make an array of a size that isn't a compile-time constant.

So, I suppose I'd better finish the Go book and move on to learning Rust next week before I need it.

