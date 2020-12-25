+++
title = "Advent of Code 2020 — day 24 remade"
date = 2020-12-25T07:21:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

I wanted to get back to yesterday’s puzzle, and I have a little time before I need to run off…

{{< tweet 1342090691992838144 >}}

The use of `findall()` I refer to in the tweet is this. You can split the input using a regular expression, and then map each input code to a direction. If you combine that with a `reduce()` you get a very succinct parser:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/24/input.txt')
tiles = f.read().strip().split()

DIRECTIONS = {
    'ne':  1 + 1j,
    'e':   2,
    'se':  1 - 1j,
    'sw': -1 - 1j,
    'w':  -2,
    'nw': -1 + 1j
}

import re
from functools import reduce

def tile_location(tile):
    return reduce(
        lambda x, y: x + DIRECTIONS[y],
        re.findall(r'(ne|e|se|sw|w|nw)', tile),
        0
    )
```

That piece I am shamelessly stealing. It is much nicer than my [original code](https://mailund.dk/posts/aoc-2020-10/).

To continue solving Puzzle #1 (again), to compute the black tiles, we need the tiles that have been flipped an odd number of times. The way I used a set earlier is smarter than the code below—it is a little easier to read and a lot faster—but this was a fun way to do it:

```python
from collections import Counter

def flip_tiles(tiles):
    counts = Counter(tiles)
    return { tile for tile in counts if counts[tile] % 2 }
```

And that is all it takes to solve Puzzle #1:

```python
tiles = flip_tiles(map(tile_location, tiles))
print(f"Puzzle #1: {len(tiles)}")
```

For Puzzle #2, I had a class for tracking the floor, but since I was only keeping track of the black tiles anyway, I might as well solve everything with set operations. With a few helper functions, we can navigate the floor from the black tiles:

```python
def neighbours(tile):
    return { tile + n for n in DIRECTIONS.values() }
def black_neighbours(tile, black):
    return len(black & neighbours(tile))

def black_tiles(tiles):
    return tiles
def white_tiles(tiles):
    return set.union( *({ x for x in neighbours(tile) if x not in tiles }
                        for tile in tiles) )
```

When updating the floor, there are black tiles we need to remove and white tiles we need to add (by flipping them to black), and it is a simple case of mapping through the black and white tiles to compute a set of tiles to remove and a set of tiles to add:

```python
def update(tiles):
    to_remove = {
        b for b in black_tiles(tiles)
          if not (1 <= black_neighbours(b, tiles) <= 2)
    }
    to_add = {
        w for w in white_tiles(tiles)
          if black_neighbours(w, tiles) == 2
    }
    tiles.difference_update(to_remove)
    tiles.update(to_add)

def evolve(tiles, n):
    for _ in range(n):
        update(tiles)
    return tiles
```

And that solves Puzzle #2.

```python
print(f"Puzzle #2: {len(evolve(tiles, 100))}")
```


