+++
title = "Advent of Code 2020 — days 09–11"
date = 2020-12-15T06:48:39+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++



## Day 09 —

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


def cumsum(x):
    y = [0, *x]
    for i in range(1,len(x)):
        y[i] += y[i - 1]
    return y

def weakness(x):
    acc = cumsum(x)
    for int_len in range(len(acc), 0, -1):
        for int_start in range(len(acc) - int_len):
            if acc[int_start + int_len] - acc[int_start] == invalid:
                start = int_start
                end = int_start + int_len
                intv = x[start:end]
                return min(intv) + max(intv)

print(f"Puzzle #2: {weakness(x)}")
```

## Day 10 —

```python
f = open('/Users/mailund/Projects/adventofcode/2020/10/test.txt')
adapters = list(sorted(map(int, f.read().split())))
charges = [0, *adapters, 3 + adapters[-1]]

# Puzzle 1
from collections import Counter
cnt = Counter(charges[i] - charges[i-1] for i in range(1,len(charges)))
print('Puzzle #1:', cnt[1] * cnt[3])
```

```python
dynprog = [None] * len(charges)
dynprog[len(charges) - 1] = 1   # basis is one, you have to include the device
for i in range(len(charges) - 2, -1, -1):
    # For each adaptor, check how many paths you get for each
    # valid choice of the next adaptor.
    cnt = 0
    for j in range(i+1,len(charges)):
        if charges[j] - charges[i] > 3: break
        cnt += dynprog[j]
    dynprog[i] = cnt
print('Puzzle #2:', dynprog[0])
```

```python
def count_paths(charges):
    tbl = {0: 1}
    for i in charges[1:]:
        tbl[i] = sum(tbl.setdefault(j, 0) for j in range(i-3,i))
    return tbl[i]
print(f'Puzzle #2: {count_paths(charges)}')
```




## Day 11 —

```python
## Puzzle #1:
f = open('/Users/mailund/Projects/adventofcode/2020/11/test.txt')
x = [line.strip() for line in f.readlines()]

def local_map(x, i, j):
    seat = x[i][j]
    adjecant = [ x[i+k][j+l] for l in [-1,0,1] if 0 <= j+l < len(x[0])
                             for k in [-1,0,1] if 0 <= i+k < len(x)
                             if (l,k) != (0,0) ]
    return seat, adjecant

def update_seat(x, i, j):
    seat, adj = local_map(x, i, j)
    if seat == 'L' and '#' not in adj:      return '#'
    if seat == '#' and adj.count('#') >= 4: return 'L'
    else:                                   return x[i][j]

def update_map(x):
    return [[update_seat(x, i, j) for j in range(len(x[0]))] for i in range(len(x))]
    
def evolve(x, last_x = None):
    return x if x == last_x else evolve(update_map(x), x)

print(f"Puzzle #1: {sum(row.count('#') for row in evolve(x))}")



## Puzzle #2: Updates to update_seat is all it takes...
def search(x, i,j, di, dj):
    """Find the first seat in direction (dx,dy)."""
    i += di ; j += dj
    while 0 <= i < len(x) and 0 <= j < len(x[0]):
        if x[i][j] in '#L': return x[i][j]
        i += di ; j += dj

def closest_seats(x, i, j):
    return [ search(x, i, j, di, dj) for dj in [-1,0,1] 
                                     for di in [-1,0,1] if (di,dj) != (0,0) ]

def update_seat(x, i, j):
    seat, adj = x[i][j], closest_seats(x, i, j)
    if seat == 'L' and '#' not in adj:      return '#'
    if seat == '#' and adj.count('#') >= 5: return 'L'
    else:                                   return x[i][j]

print(f"Puzzle #2: {sum(row.count('#') for row in evolve(x))}")
```

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


void print_map(struct map *map)
{
    printf("\n%d x %d map:\n", map->nrow, map->ncol);
    for (int i = 0; i < map->nrow; i++) {
        for (int j = 0; j < map->ncol; j++) {
            putchar(map->map[map->ncol * i + j]);
        }
        putchar('\n');
    }
    putchar('\n');
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

