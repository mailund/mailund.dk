---
title: "Prefix Doubling Attempts"
date: 2021-11-25T14:08:34+01:00
categories: [Programming]
tags: [programming, algorithms, C, Python]
---

I've been working on an algorithm for suffix array construction today. It's called *prefix doubling*, but I don't have a link, sorry. I think it comes from [this paper](https://dl.acm.org/doi/10.1145/800152.804905) but I don't have access to it at home.

Anyway, from what I can work out from Wikipedia, you iteratively do a two-level radix sort of your suffixes.

You start out with what will become your suffix array—it is just the indices into `x`—and the "rank" these suffixes have. They are not true ranks, i.e. the position they have in their sorted order, because we haven't sorted them yet, but it is a rank we update until we have them sorted.

The initial suffix array, the way I implemented it, is just the indices in increasing order, e.g. `sa = [0, 1, 2, 3, 4, 5]` and the rank is their order with respect to just the first letter in the string `x`, e.g. `x = acabab`, so `rank = [1, 3, 1, 2, 1, 2]` (rank 0 is reserved for empty strings, so we start at 1).

```
sa suffix   rank
 0   acabab    1
 1    cabab    3
 2     abab    1
 3      bab    2
 4       ab    1
 5        b    2
```

We can rearrange the `sa` according to the sorted rank to gett

```
sa suffix   rank
 0   acabab    1
 2     abab    1
 4       ab    1
 3      bab    2
 5        b    2
 1    cabab    3
```

which is a bit closer to sorted, but not quite there; the first three suffixes are out of order, as are the next two, because we never looked beyond the first character.

Now, the idea is this. Sort `sa` according to `rank[sa[i]]` and `rank[sa[i]+1]`, i.e. two consecutive ranks. This amounts to sorting with respect to the first two letters. We can do this using two bucket sorts and it amounts to giving each suffix a pair of numbers as its "rank". Since empty strings are smaller than any non-empty strings, we add the rules that `rank[k]` is zero if `k` is beyond the bound of `rank`.

```
sa   = [0, 2, 4, 3, 5, 1]
rank = [1, 3, 1, 2, 1, 2]

sa suffix   rank[sa[i]]  rank[sa[i]+1]
 0   acabab       1         3    
 2     abab       1         2
 4       ab       1         2
 3      bab       2         1
 5        b       2         0
 1    cabab       3         1
```

The pairs are `(1,3), (1,2), (1,2), (2,1), (2,0), (3,1)` and we can sort these and give them a rank

```
(1,2) = 1
(1,3) = 2
(2,0) = 3
(2,1) = 4
(3,1) = 5
```

Then, we can update our `rank` list so each suffix get the rank it has in this pair-rank. That will be the rank each suffix would have if we only sorted by the first two characters.

```
suffix     pair   rank
acabab   (1,3)   2
 cabab   (3,1)   5
  abab   (1,2)   1
   bab   (2,1)   4
    ab   (1,2)   1
     b   (2,0)   3
```

or, in sorted order according to the suffix array

```
sa suffix     pair   rank
 2     abab   (1,2)   1
 4       ab   (1,2)   1
 0   acabab   (1,3)   2
 5        b   (2,0)   3
 3      bab   (2,1)   4
 1    cabab   (3,1)   5
```

We are almost done, but the first two suffixes are still out of order; they share the first two characters so we haven't been able to order them correctly.

We now do the same thing again, look at pairs of ranks, but this time we don't look at two consecutive ranks, `rank[sa[i]]` and `rank[sa[i]+1]`, but ranks that are two characters apart, `rank[sa[i]]` and `rank[sa[i]+2]`. We already know the relative rank of strings based on their first two characters, so if we now look at ranks that are two indices apart, we are comparing prefixes of length four.

I won't do the full thing, but just the two suffixes that are out of order, suffix 2 and 4.

```
(rank[2], rank[2+2]) = (1, 1)
(rank[4], rank[4+2]) = (1, 0)
```

Assigning ranks and reordering will see these two as different ranks, with the first (string `abab`) coming after the second `ab`.

At this point, all the suffixes in the example are sorted, and we could recognise this by looking at the ranks. The ranks would all be unique, which means that we must have sorted the suffixes; we have sorted them up to prefixes of four characters, and here they are apparently all unique.

If we didn't have unique ranks here, we would do the same thing again, but this time use an offset of 4 instead of 2, in effect sorting with respect the prefixes of length eight. In general, we would use offers of `k`, sorting the suffixes with respect to prefixes of length `2k`. That is where the doubling comes in, and it ensures that we can't do more than log n iterations. Each iteration takes O(n) for the bucket sorts, so the total running time is O(n \log n). It is possible to construct suffix arrays in O(n), of course, so why is this interesting? Well, I want to see if the low overhead means that this algorithm can still beat the linear time algorithms.

I prototyped the algorithm in Python. My implementation looks like this:

```python
def remap(x: str) -> tuple[list[int], int]:
    """
    Translate a string, x, into a list of ranks.

    The ranks start at 1, leaving 0 for a sentinel value.
    """
    Σ = {a: i+1 for i, a in enumerate(sorted(set(x)))}
    return [Σ[a] for a in x], len(Σ) + 1


def get_rank(rank: list[int], i: int) -> int:
    """
    Get the rank of the element at index i.

    Index into rank but returning sentinel when indexing
    beyond the end.
    """
    return rank[i] if i < len(rank) else 0


def bsort(sa: list[int], rank: list[int], out: list[int],
          k: int, σ: int) -> None:
    """
    Bucket sort.

    Bucket sort sa with keys in rank at offset k.
    The result is put in out.
    """
    buckets = [0] * σ
    for i in sa:
        r = get_rank(rank, i + k)
        buckets[r] += 1
    acc = 0
    for i, b in enumerate(buckets):
        buckets[i] = acc
        acc += b
    for i in sa:
        r = get_rank(rank, i + k)
        out[buckets[r]] = i
        buckets[r] += 1


def update_rank(sa: list[int], rank: list[int],
                out: list[int], k: int) -> int:
    """
    Compute new rank after sorting.

    Update rank to reflect the order we have at
    (rank[sa[i]], rank[sa[i]+k]) and put the result in rank.
    Return the new alphabet size.
    """
    σ = 1  # leave 0 for sentinel
    out[sa[0]] = σ
    prev_rank = (rank[sa[0]], get_rank(rank, sa[0] + k))
    for i in sa[1:]:
        this_rank = (rank[i], get_rank(rank, i + k))
        σ += (prev_rank != this_rank)
        prev_rank = this_rank
        out[i] = σ
    return σ + 1


def prefix_doubling_construction(x: str) -> list[int]:
    """Construct a suffix array for x using prefix doubling."""
    rank, σ = remap(x)
    sa = list(range(len(x)))
    buf = [0] * len(x)

    k = 1
    while σ < len(x) + 1:
        # radix sort with offset k
        bsort(sa, rank, buf, k, σ)
        bsort(buf, rank, sa, 0, σ)

        # compute the new ranks
        σ = update_rank(sa, rank, buf, k)
        rank, buf = buf, rank  # switch buffers to get new ranks in ranks

        # next iteration with twice the offset
        k *= 2

    return sa


x = "mississippimississippimississippi"
sa = prefix_doubling_construction(x)
for i in sa:
    print(x[i:])
```

It is close enough to working that I decided to implement it in C. I want the speed of C before I do any benchmarking and comparison.

I ended up with this:

```c
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NO_CHARS (1 << CHAR_BIT)
#define SWAP(a, b)             \
    do                         \
    {                          \
        __typeof__(a) tmp = a; \
        a = b;                 \
        b = tmp;               \
    } while (0)

static void *faultless_malloc(size_t size)
{
    void *mem = malloc(size);
    if (!mem)
        abort(); // no error handling for me today!
    return mem;
}

// maps the letters in x to integers in the range [0, ..., sigma - 1]
// Stores the length of n in *n and the alphabet size in *sigma.
static uint32_t *remap(char const *x, uint32_t *n, uint32_t *sigma)
{
    uint32_t alphabet[NO_CHARS] = {0};

    // run through x and tag occurring letters
    unsigned char const *unsigned_x = (unsigned char const *)x, *s;
    for (s = unsigned_x; *s; s++)
        alphabet[*s] = 1;
    *n = s - unsigned_x; // length of x, not including '\0'

    // assign numbers to each occurring letter
    *sigma = 1;
    for (int a = 0; a < NO_CHARS; a++)
    {
        if (alphabet[a])
            alphabet[a] = (*sigma)++;
    }

    // map each letter from x to its number and place them in mapped
    uint32_t *mapped = faultless_malloc(*n * sizeof *mapped), *a;
    for (a = mapped, s = unsigned_x; *s; a++, s++)
        *a = alphabet[*s];

    return mapped;
}

// Allocate and initialise what will eventually become the suffix array
// with indices [0, 1, 2, ..., n - 1].
static uint32_t *alloc_sa(uint32_t n)
{
    uint32_t *sa = faultless_malloc(n * sizeof *sa);
    for (uint32_t i = 0; i < n; i++)
    {
        sa[i] = i;
    }
    return sa;
}

// Get the rank from array rank, but if you index beyond the end,
// you get the sentinel letter 0.
static inline int get_rank(uint32_t n,
                           uint32_t rank[static n],
                           int i)
{
    return (i < n) ? rank[i] : 0;
}

// Bucket sort the elements sa according to the rank[sa[i]+k]
// (with padded zero sentinels). The result goes to out.
static void bsort(uint32_t n,
                  uint32_t sa[static n],
                  uint32_t rank[static n],
                  uint32_t out[static n],
                  uint32_t k,
                  uint32_t buckets[static n],
                  uint32_t sigma)
{
    memset(buckets, 0, sigma * sizeof *buckets);

    for (uint32_t i = 0; i < n; i++)
    {
        buckets[get_rank(n, rank, sa[i] + k)]++;
    }
    for (uint32_t acc = 0, i = 0; i < sigma; i++)
    {
        uint32_t b = buckets[i];
        buckets[i] = acc;
        acc += b;
    }
    for (uint32_t i = 0; i < n; i++)
    {
        uint32_t j = sa[i];
        uint32_t r = get_rank(n, rank, j + k);
        out[buckets[r]++] = j;
    }
}

// For each element in sa, assumed sorted according to
// rank[sa[i]],rank[sa[i]+k], work out what rank
// (order of rank[sa[i]],rank[sa[i]+k]) each element has
// and put the result in out.
static uint32_t update_rank(uint32_t n,
                            uint32_t sa[static n],
                            uint32_t rank[static n],
                            uint32_t out[static n],
                            uint32_t k)
{
#define PAIR(i, k) (((uint64_t)rank[sa[i]] << 32) | \
                    (uint64_t)get_rank(n, rank, sa[i] + k))

    uint32_t sigma = 1; // leave zero for sentinel
    out[sa[0]] = sigma;

    uint64_t prev_pair = PAIR(0, k);
    for (uint32_t i = 1; i < n; i++)
    {
        uint64_t cur_pair = PAIR(i, k);
        sigma += (prev_pair != cur_pair);
        prev_pair = cur_pair;
        out[sa[i]] = sigma;
    }

    return sigma + 1;

#undef PAIR
}

struct suffix_array
{
    uint32_t len;
    uint32_t *buf;
};

// Construct a suffix array using prefix-doubling
struct suffix_array prefix_doubling_sa_construction(char const *x)
{
    uint32_t n, sigma;
    uint32_t *rank = remap(x, &n, &sigma);
    uint32_t *sa = alloc_sa(n);
    uint32_t *buckets = faultless_malloc(n * sizeof *buckets);
    uint32_t *buf = faultless_malloc(n * sizeof *buf);

    for (uint32_t k = 1; sigma < n + 1; k *= 2)
    {
        bsort(n, sa, rank, buf, k, buckets, sigma); // result in buf
        bsort(n, buf, rank, sa, 0, buckets, sigma); // result back in sa
        sigma = update_rank(n, sa, rank, buf, k);   // new rank in buf
        SWAP(rank, buf);                            // now new rank is back in rank
    }

    free(rank);
    free(buf);

    return (struct suffix_array){.len = n, .buf = sa};
}

int main(void)
{
    char *x = "mississippimississippimississippi";
    struct suffix_array sa = prefix_doubling_sa_construction(x);

    for (uint32_t i = 0; i < sa.len; i++)
    {
        printf("%s\n", x + sa.buf[i]);
    }
    free(sa.buf);

    return 0;
}
```

And then I sorta stopped.

I think it works; it is a fairly straightforward translation of the Python code, and if it works on three mississippis it must be working.

But I use 3n integers in addition to the suffix array, and that feels excessive. I just don't know how to make the sorting and ranking in-place.

Any ideas?

