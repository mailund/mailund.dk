+++
title = "Advent of Code 2020 — days 09–11"
date = 2020-12-16T09:48:39+01:00
draft = false
tags = ["python", "c", "programming"]
categories = ["Programming"]
markup = "md"
+++

Another day, another post with solutions to 2020 [Advent of Code](https://adventofcode.com). I am slowly catching up with the actual puzzles, and I will probably get there soon. After that, there will probably be one day per post, except that I expect that the 24th and 25th will be something I leave for after Christmas. I’m not sure I will be allowed to sit and write over Christmas. We will see.

Anyway, there are some interesting puzzles in this post, and one algorithmic technique that you absolutely *must* have in your algorithmic toolbox: *dynamic programming*. Day 10’s Puzzle #2 is trivial to solve using this technique, but without it, I wouldn’t really know where to start.

But first, day nine, of course.

## Day 09 — Encoding Error

There is a [long description](https://adventofcode.com/2020/day/9) of an encryption scheme, where you can find a vulnerability if you have a number, where you cannot find a pair of numbers in the previous *p* numbers that sum to the next. In the example, *p* is five, in the puzzle input, it is 25.

Finding a pair of numbers that sum to a third number is something we did in [Day 1](https://mailund.dk/posts/aoc-2020-1/), and Puzzle #1 is easy to brute-force. I use the trick with the set in my implementation, but it would be fast enough if you used a double loop instead.

This is a helper function I use, that checks if I have a pair of numbers that sum to `x[i]` in the previous `p` numbers:

```python
def valid(i): # solution from day 01
    prev, curr = x[i-p:i], x[i]
    z = { *((curr - y) for y in prev) }
    return any(y in z for y in pred)
```

I extract the sequence of numbers from a list, `x`, and the current number as `x[i]`. Then I build the set `z` that lets me answer if I have a pair that sums to `x[i]`, and finally I use the function `any()` to check if any of the elements in the previous `p` numbers are in `z`. If so, we have a pair that sums to `x[i]`. Check Day 1 for how this works.

We need to find the first number that doesn’t satisfy this, so we want to run `i` from `p` (the first index where we can get *p* previous numbers) and up, until we find one that doesn’t satisfy the `valid(i)` check. You can do this in a simple loop

```python
for i in range(p, len(x)):
    # check index i …
```

but there is a function in `itertools` called `dropwhile()` that can do it for you. It takes a predicate and an iterator as argument, and it will give you the iterator when it has reached the first element that doesn’t satisfy the predicate. So if we write

```python
dropwhile(valid, range(p, len(x)))
```

we will get the sequence of indices, starting at the first invalid index. If you have an iterator, you can get the next value with the function `next()`, so

```python
i = next(dropwhile(valid, range(p, len(x))))
```

is the first invalid index, and we are looking for `x[i]`. Putting it all together, we get this solution for Puzzle #1:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/09/input.txt')
x = list(map(int, f.read().split()))
p = 25

# Just brute force the first task... it is too simple to bother
# with being smart...
from itertools import dropwhile
def find_invalid(x, p):
    def valid(i): # solution from day 01
        prev, curr = x[i-p:i], x[i]
        z = { *((curr - y) for y in prev) }
        return any(y in prev for y in z)

    i = next(dropwhile(valid, range(p, len(x))))
    return x[i]

invalid = find_invalid(x, p)
print(f"Puzzle #1: {invalid}")
```

I save the invalid number in `invalid`, because we need it for Puzzle #2.

In Puzzle #2, we have to find the largest subsequence in the numbers that sum to `invalid`, and then add the smallest and largest number in that interval. You can iterate through all indices `i` and `j > i`, then sum the numbers in `x[i:j]`, and thus generate all the sum of subsequences. It would be an   \\( O(n^3) \\) running time (quadratic time for iterating over the two indices and a linear time scan to add the numbers in the subsequence). I didn’t brute force it quite like this, but almost.

There is an easy way to shave off one factor of *n*, that you will be familiar with if you do any algorithms in bioinformatics, where working with subsequences is hardly a rare occurrence. If you have a sequence of numbers, `x`, you can compute the cumulative sum `y = cumsum(x)`, where `y[i] = sum(x[:i])`. There is a `cumsum()` in `Numpy`, 

```python
from numpy import cumsum
```

but you can roll your own like this:

```python
def cumsum(x):
    y = x[:]
    for i in range(1,len(x)):
        y[i] += y[i - 1]
    return y
```

It should be obvious that this is a linear time algorithm, so we spend \\( O(n) \\) on this preprocessing. I want a slightly modified cumulative sum, where I have zero at index 0, and where `y[i]`=\\(\sum_{j=0}^i\\)`x[i]`, i.e., I include index `i` in the sum, so I will adjust it as `y = [0, *cumsum(x)]`, but it is obviously still a linear time preprocessing.

Then, since `y[i]`=\\(\sum_{j=0}^i\\)`x[i]`, `y[j]-y[i]`=\\(\sum_{k=i}^{j-1}\\)`x[i]`, for `j>i`, i.e., `y[i]-y[j] = sum(x[i:j])`. The preprocessing gives me a constant time way to get the sum over a subsequence. This is a generic trick, and one you should reach for every time you see something like partial sums. It works almost every time.

For the search for the longest invalid sequence, I didn’t do anything clever. I am not sure you can do better than \\(O(n^2)\\), and for data of this size, a quadratic time algorithm is fast enough. Maybe, and only maybe, if I had to run this code thousands of times, I would think a little deeper, but I didn’t bother here.

I didn’t do nested for-loops over index `i` and `j`, though. I could, but I am looking for the longest invalid subsequence, so I might as well run through the subsequences in order of decreasing length. It is just as easy, and if I do it that way, I can terminate as soon as I find an invalid sequence. It will still be quadratic time theoretically, but in practise you will break the loop faster, and you don’t have to search for the longest sequence after you have encountered all the invalid ones. So I made an outer loop over interval lengths, then an inner for the start value, and then used the cumulative sum to check the intervals:

```python
def weakness(x):
    cs = [0, *cumsum(x)]
    for int_len in range(len(cs), 0, -1):
        for int_start in range(len(cs) - int_len):
            if cs[int_start + int_len] - cs[int_start] == invalid:
                start = int_start
                end = int_start + int_len
                intv = x[start:end]
                return min(intv) + max(intv)

print(f"Puzzle #2: {weakness(x)}")
```

## Day 10 — Adapter Array

I really liked [Day 10](https://adventofcode.com/2020/day/10), because I got to use one of my favourite algorithmic tricks in Puzzle #2.

But we need to do Puzzle #1 before we can see Puzzle #2, so let’s look at [the description](https://adventofcode.com/2020/day/10). We have a set of adapters that can connect to other adapters 1, 2, or 3 voltages below them (or above them, this is symmetric if you think about it). We have an outlet with voltage zero, and we are aiming to connect a device that is three higher than the largest adapter.

The description about finding a way to connect them is mostly misdirection. If they connect the way it is described, then any  sequence of connections must handle them in increasing order, so we are really only asked to sort them, when we connect them.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/10/test.txt')
adapters = list(sorted(map(int, f.read().split())))
charges = [0, *adapters, 3 + adapters[-1]]
```

I sort the `adapters`, and then I put them in a list, `charges`, that also include the outlet and the final device.

For Puzzle #1, we are then asked to consider the differences between the voltages in this sorted list, count how many differences are one and three, and multiply the two together. To count occurrences in a list, we turn to our trusted friend `Counter` from `collections`, and then we are pretty much done:

```python
# Puzzle 1
from collections import Counter
cnt = Counter(charges[i] - charges[i-1] for i in range(1,len(charges)))
print('Puzzle #1:', cnt[1] * cnt[3])
```

The expression inside the call to `Counter()` gives us all the differences, `Counter()` counts them, and we can get those of distance 1 from `cnt[1]` and those of distance 3 from `cnt[3]`. 

Since we know that they can at most connect to others that are three voltages apart, a distance of 3 is the maximum we could see if the problem is solvable. There doesn’t appear to be any distances of zero or two, but there is nothing in the description that indicates that we couldn’t have had that. If our input were adaptors 2 and 4, for example, we would. We can connect the outlet to 2, then 2 to 4, and then 4 to the device at 4+3=7. Then `cnt` would be `Counter({2: 2, 3: 1})`. Anyway, that doesn’t matter, because we have already solved Puzzle #1.

For the second puzzle, we are asked how many possible ways there are to connect the adapters, so we can go from the outlet to the device. If you read the description as if you have to assemble different permutations of adaptors, then don’t. Any valid path is sorted, so we are talking about subsets of `charges`. If you then think that you need to check all subsets, and count the valid ones, remember that if you have a set of size \\(n\\), then there are \\( 2^n \\) such subsets. You don’t want to go there either.

With the puzzle, it helps to think about the question as a graph problem, I think. The adaptors are node, and if we think of the problem as a directed acyclic graph, a DAG, then we can say that we have an edge from each adaptor to those that are at most three charges higher. We have to count the number of paths from the source, the outlet, to the target, the device. Framed this way, we see that we have a problem similar to the one with bags on [Day 07](https://mailund.dk/posts/aoc-2020-2/). And we can solve it similarly.

We can consider the problem recursively. If we let \\( p(v) \\) denote the number of paths from node \\( v \\) to the target, then \\( p(t)=1 \\) for the target node, and \\( p(v)=\sum_{v\to w}p(w), \\) where \\( v\to w \\) means that you can go from node \\( v \\) to \\( w, \\) for all other nodes.

A straightforward implementation of this, similar to the graph exploration we did with the bags, can look like this:

```python
from itertools import takewhile
def count_paths(charges):
    return takewhile(lambda w: charges[w] - charges[v] <= 3,
                     range(v + 1, len(charges)))
    def count(v):
        if v == len(charges) - 1: return 1
        return sum(count(w) for w in neighbours(v))
    return count(0)
print(f'Puzzle #2: {count_paths(charges)}')
```

The `neighbours()` function gives us the nodes we can reach from `v`, and it uses the `takewhile()` function from `itertools` to adapt the `range()` sequence to the prefix we want. It is similar to the `dropwhile()` function from above, it just gives us a prefix that satisfy the predicate instead of removing it.

This solution will work, but it will be *slow*, and I didn’t even attempt it. I didn’t write it up until this blog post. When we are exploring the graph in this way, we are in effect attempting to explore all powersets of `charges`, and exploring exponentially many paths is usually a no-go. (In Day 14, it was the way to go, and that still bothers me).

But there is an easy fix, and it is one we have already used: *memorization*. We used it with the bags, but we didn’t gain more than a few milliseconds there. If we use it now, we go from I don’t know how long (because I didn’t bother timing it) to a solution that runs in milliseconds. Import `cache` from `functors`, put `@cache` in front of the recursive traversal, and you are done:

```python
from functools import cache
from itertools import takewhile
def count_paths(charges):
    def neighbours(v):
        return takewhile(lambda w: charges[w] - charges[v] <= 3,
                         range(v + 1, len(charges)))
    @cache
    def count(v):
        if v == len(charges) - 1: return 1
        return sum(count(w) for w in neighbours(v))
    return count(0)
print(f'Puzzle #2: {count_paths(charges)}')
```

This wasn’t my first attempt, though. I didn’t think of it until later. My experience led me directly to *dynamic programming* when I saw the problem, and that solution is a little different.

Dynamic programming and memorisation are doing the same thing. You have to recursively compute some value, and if you are in the situation where you will make many calls with the same argument, as above but unlike the bag puzzles, then you can save time by remembering the result of the first call. Without remembering the calls, in the current puzzle, we have an exponential running time. If we remember the results of a call, then it is linear—in each call you get at most three other values that you add together, so you use constant time per call, whether it is the first or subsequent calls, and we only have \\( O(n) \\) possible different values to call the `count()` function with. So linear time in total.

You are not always this lucky, so it is not a technique that always work, but it is applicable surprisingly often. I am exaggerating a little when I tell my students that half of bioinformatics is variations of this, but I am not entirely wrong.

The difference between memorisation, the way we have used it here, and dynamic programming, is in how we remember computed values. With memorisation, in your function you need to check at each call whether the parameters are some that you have seen before, and if so, return the cached value. If not, you compute the value, and put the result in your table. It looks simple when we can handle it with a decorator, but when you implement it yourself, there can be quite some work involved, and there is always some overhead. The overhead, when you go from an exponential time algorithm to a polynomial one is worth it, of course, but it is still there.

With dynamic programming, you build your table up front, and then you compute the values in order, such that you always have the values for the recursion when you need them. Instead of calling recursively from the beginning of the list of adaptors, and remembering all the recursive calls, we can start from the last device, where we know the value should be 1, and fill up a table as we move backwards. For each node, we look at nodes later in the list, so if we fill the list from the right towards the left, we never need to check if we have a value. We know that we have it when we need it.

A straightforward implementation looks like this:


```python
def count_paths(charges):
    def neighbours(v):
        return takewhile(lambda w: charges[w] - charges[v] <= 3,
                         range(v + 1, len(charges)))

    count = [None] * len(charges)
    count[len(charges) - 1] = 1
    for v in range(len(charges) - 2, -1, -1):
        count[v] = sum(count[w] for w in neighbours(v))

    return count[0]
print(f'Puzzle #2: {count_paths(charges)}')
```

I can’t see any performance difference between the two versions—Python’s dictionaries are pretty fast—but I am also used to implementing these things in C, where it is easy to make a table and hard to implement a custom table when you need it.

I like the `@cache` version, because it is such a tiny change to the simple recursion, with so much bang for the buck, but I still think I like the dynamic programming solution a little more. With dynamic programming, I can see exactly how long the algorithm will, I can immediately see the space complexity as well, and that is a lot harder with the `@cache` solution. But if you are in a hurry, you get the same boost with `@cache` as you do with dynamic programming. (But try to arrange your life so you are never in that much of a hurry).

Another solution came to me later. It does roughly the same as the dynamic programming solution, but it uses a different representation of the graph. The two previous solutions use indices into `charges` as the nodes, but we can also use the voltage values. If we have a node `w`, we can get there from any `v` with `v-w <= 3`. So we can build the table from left to right. However, with this representation, some of the values we get for `v` might not be in `charges`, and we shouldn’t include those in the sum. They should count as zero. 

We can imagine that the graph has nodes from zero to `charges[-1]`, and count how many paths there are from the source to a node \\( w. \\) It is \\( p(w)=\sum_{v\to w}p(v). \\) We have just flipped the order of the computation, so the base case is zero and we look to the left instead of the right in the recursion. We can put a one in \\( p(0)=1, \\) and then run through the adapters in `charges`, and look back three voltage values. If we that way look at a value \\( v \\) that isn’t in `charges`, we will give it contribution \\( p(v)=0. \\) You can implement this using both dictionaries and lists quite easily:

```python
def count_paths(charges):
    tbl = {0: 1}
    for w in charges[1:]:
        tbl[w] = sum(tbl.setdefault(v, 0) for v in range(w-3,w))
    return tbl[w]
print(f'Puzzle #2: {count_paths(charges)}')

def neighbours(w):
    return range(max(0, w - 3), w)
def count_paths(charges):
    tbl = [1] + [0] * charges[-1]
    for w in charges[1:]:
        tbl[w] = sum(tbl[v] for v in neighbours(w))
    return tbl[w]
print(f'Puzzle #2: {count_paths(charges)}')
```

Dynamic programming/memorization for the win!



## Day 11 — Seating System

[Day 11](https://adventofcode.com/2020/day/11) changes pace a little. This time, we are not looking for clever algorithms, but playing the [Conaway’s Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life).

We have a map of occupied or free seats plus floor-space, and we have a rule for evolving such maps. For each index in the map, we can look around and count occupied chairs, and then we update the location based on how many chairs we see there, plus the state of the current seat. That is pretty much all there is to both puzzles. So not surprisingly, I spent a lot of time on getting it right. At one place in my code, I used `len(x)` where I should be using `len(x[0])`. I guess the lesson is that it is important to keep track of which dimension you are looking at. I was unlucky, and for my input `len(x[0]) > len(x)`, so I didn’t get a crash, just the wrong number. That took a while to fix.

For me (correct) solution, I have a function that extracts the symbols around a location. It later turns out that it would be enough go count occupied chairs, but you never know what Puzzle #2 will throw at you, so I extracted all the adjacent cells.

```python
def local_map(x, i, j):
    seat = x[i][j]
    adjecant = [ x[i+k][j+l] for l in [-1,0,1] if 0 <= j+l < len(x[0])
                             for k in [-1,0,1] if 0 <= i+k < len(x)
                             if (l,k) != (0,0) ]
    return seat, adjecant
```

Then, I wrote a function that, depending on local context, would give the the symbol that should be in the next map in the evolution:

```python
def update_seat(x, i, j):
    seat, adj = local_map(x, i, j)
    if seat == 'L' and '#' not in adj:      return '#'
    if seat == '#' and adj.count('#') >= 4: return 'L'
    else:                                   return x[i][j]
```

And finally, a function that would create a new map by applying the local changers everywhere, and another function for evolving the map until we reach a fix point.

```python
def update_map(x):
    return [[update_seat(x, i, j) for j in range(len(x[0]))] for i in range(len(x))]
    
def evolve(x, last_x = None):
    return x if x == last_x else evolve(update_map(x), x)
```

To solve the puzzle, count how many occupied seats there ar ein the final map:

```python
## Puzzle #1:
f = open('/Users/mailund/Projects/adventofcode/2020/11/test.txt')
x = [line.strip() for line in f.readlines()]
print(f"Puzzle #1: {sum(row.count('#') for row in evolve(x))}")
```

For Puzzle #2, the rule for updating fields changes slightly. We need to search in the eight directions around the location to find the first seat. You can do that by writing a function that takes step-sizes in dimensions \\( x \\) and \\( y. \\)


```python
def search(x, i,j, di, dj):
    """Find the first seat in direction (dx,dy)."""
    i += di ; j += dj
    while 0 <= i < len(x) and 0 <= j < len(x[0]):
        if x[i][j] in '#L': return x[i][j]
        i += di ; j += dj
```

Later you can use `(-1,-1),(-1,0),(-1,1),…,(1,-1),(1,0),(1,1)` to give you the directions. You need all combinations of `[-1,0,1] x [-1,0,1]` except `(0,0)`.

```python
def closest_seats(x, i, j):
    return [ search(x, i, j, di, dj) for dj in [-1,0,1] 
                                     for di in [-1,0,1] if (di,dj) != (0,0) ]
```

We get the closes seats in all direction, except that `search()` will return `None` if we run off the map, but that is fine. By now, I knew that only needed to know the number of occupied seats, so I could just have counted. In any case, `None` works fine as an indicator for a non-occupied seat.

We can use the `closest_seats()` functions to write a function for updating one cell, and then use that function in the `evolve()` function from before.

```python
def update_seat(x, i, j):
    seat, adj = x[i][j], closest_seats(x, i, j)
    if seat == 'L' and '#' not in adj:      return '#'
    if seat == '#' and adj.count('#') >= 5: return 'L'
    else:                                   return x[i][j]

# Puzzle #2:
print(f"Puzzle #2: {sum(row.count('#') for row in evolve(x))}")
```

The code is a little slow. It takes me around nine seconds to run it on the full input. So I implemented it in C as well, where I can run it in 80 milliseconds. The idea in the C code is exactly the same, so I will not go through it in detail. You should be able to recognise all the components for the solution. The only major change is that I count occupied seats instead of building lists of cells. That is a lot easier when in C, and I knew the full problem by the time I got to this implementation.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

// Code for dealing with maps...
struct map {
    int nrow, ncol;
    char map[];
};
#define IDX(M,I,J)  ((M)->map[(M)->ncol * (I) + (J)])
#define SEAT_OCC(M,I,J) \
    ( ((I) < 0) ? 0 : ((I) >= (M)->nrow) ? 0 : \
      ((J) < 0) ? 0 : ((J) >= (M)->ncol) ? 0 : \
      (IDX(M,I,J) == '#') )
#define FIXPOINT(OLD,NEW) \
    (!memcmp((OLD)->map, (NEW)->map, (OLD)->nrow * (OLD)->ncol))

static struct map *new_map(int nrow, int ncol)
{
    struct map *map = malloc(offsetof(struct map, map) + nrow * ncol);
    if (map) { map->nrow = nrow; map->ncol = ncol; }
    return map;
}
static struct map *clone_map(struct map *map)
{
    struct map *clone = new_map(map->nrow, map->ncol);
    memcpy(clone->map, map->map, map->nrow * map->ncol);
    return clone;
}

static inline
int count_occupied(struct map *map)
{
    int n = map->nrow * map->ncol;
    int count = 0;
    for (char *x = map->map; x < map->map + n; x++)
        count += (*x == '#');
    return count;
}


// Generic code for evolving a map
typedef char (*local_upd)(struct map *map, int i, int j, char old);
static void update_map(struct map *new_map, struct map *old_map, local_upd upd)
{
    char *x = new_map->map, *y = old_map->map;
    for (int i = 0; i < new_map->nrow; i++) {
        for (int j = 0; j < new_map->ncol; j++)
            *x++ = upd(old_map, i, j, *y++);
    }
}

static void evolve(struct map *input_map, local_upd upd)
{
    struct map *helper = clone_map(input_map);
    struct map *maps[] = { input_map, helper };
    int cur_map = 0;
    do {
        update_map(maps[(cur_map + 1) % 2], maps[cur_map % 2], upd);
        cur_map++;
    } while (!FIXPOINT(maps[0], maps[1]));
    free(helper);
}

// Puzzle 1 ---------------------------------------------------
static inline
int count_adjecant(struct map *map, int i, int j)
{
    int count = 0;
    for (int k = -1; k <= 1; k++) {
        for (int l = -1; l <= 1; l++)
            // branching-less condition
            count += (k != 0 || l != 0) * SEAT_OCC(map, i+k, j+l);
    }
    return count;
}

static
char update_seat_puzzle1(struct map *map, int i, int j, char old_seat)
{
    if (old_seat == '.')                              return old_seat;
    int occ_count = count_adjecant(map, i, j);
    if      (old_seat == 'L' && occ_count == 0)       return '#';
    else if (old_seat == '#' && occ_count >= 4)       return 'L';
    else                                              return old_seat;
}

static int puzzle1(struct map *map)
{
    evolve(map, update_seat_puzzle1);
    return count_occupied(map);
}

// Puzzle 2 ---------------------------------------------------
static inline 
int seat_direction(struct map *map, int i, int j, int di, int dj)
{
    if (di == 0 && dj == 0) return 0; // easier to test this here
    int n = map->nrow, m = map->ncol;
    i += di; j += dj;
    while (i >= 0 && i < n && j >= 0 && j < m) {
        char seat = IDX(map,i,j);
        if (seat == '#') return 1;
        if (seat == 'L') return 0;
        i += di; j += dj;
    }
    return 0;
}

static inline
int count_neighbours(struct map *map, int i, int j)
{
    int count = 0;
    for (int di = -1; di <= 1; di++) {
        for (int dj = -1; dj <= 1; dj++)
            count += seat_direction(map, i, j, di, dj);
    }
    return count;
}

static 
char update_seat_puzzle2(struct map *map, int i, int j, char old_seat)
{
    if (old_seat == '.')                              return old_seat;
    int occ_count = count_neighbours(map, i, j);
    if      (old_seat == 'L' && occ_count == 0)       return '#';
    else if (old_seat == '#' && occ_count >= 5)       return 'L';
    else                                              return old_seat;
}

static int puzzle2(struct map *map)
{
    evolve(map, update_seat_puzzle2);
    return count_occupied(map);
}

// only for IO. Not pretty, but don't care
#define N 1000
char input_buf[N];
static struct map *read_map(void)
{
    // getting too much memory for the initial map, but who cares?
    struct map *map = new_map(N, N);
    fgets(input_buf, N, stdin);
    int ncol = strlen(input_buf) - 1;
    int nrow = 0;
    memcpy(map->map + nrow++ * ncol, input_buf, ncol);
    while (fgets(input_buf, N, stdin)) {
        memcpy(map->map + nrow++ * ncol, input_buf, ncol);
    }
    // getting the correct dimensions
    map->nrow = nrow; map->ncol = ncol;
    return map;
}


int main(void)
{
    struct map *map = read_map();
    struct map *puzzle1_clone = clone_map(map);
    printf("Puzzle #1: %d\n", puzzle1(puzzle1_clone));
    free(puzzle1_clone);

    printf("Puzzle #2: %d\n", puzzle2(map));
    free(map);

    return 0;
}
```

