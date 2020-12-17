+++
title = "Advent of Code 2020 — days 17-18"
date = 2020-12-18T06:51:59+01:00
draft = true
tags = ["python", "programming"]
categories = ["Programming"]
+++



## Day 17 — Conway Cubes

On [Day 17](https://adventofcode.com/2020/day/17) we return to [Conway’s Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life). We saw it last on [day 11](https://mailund.dk/posts/aoc-2020-3/), where we evaluated maps according to local rules. Now, we have to do the same thing again, but this time, the map we evaluate is infinite!

How do we represent an infinite map? The obvious answer is that we don’t represent all coordinates explicitly. We start out with infinitely many inactive coordinates and a finite set of active coordinates. The rule for changing the map can only make finitely many active coordinates, because it needs active coordinates to create one. This tells us, that in finitely many steps, we can only have finitely many active coordinates. If we keep track of the coordinates that are active only, then we have a finite representation of a map.

I wrapped up this idea in a class, `Map`, that pretends to be a table—it implements `__getitem__()` and `__setitem__()`, but it never inserts inactive coordinates, and under the hood, it uses a set of active coordinates to represent the state. Otherwise, it closely resemble the code from day 6 in how it works.

```python
from itertools import product
_NEIGHBOUR_OFFSETS = (-1,0,1)
_NEIGHBOURS = [(i,j,k) for i,j,k in product(*([_NEIGHBOUR_OFFSETS]*3)) if (i,j,k) != (0,0,0)]

def expand_dim(val, dim):
    return (min(val, dim[0]), max(val+1,dim[1]))

class Map(object):
    def __init__(self):
        self.active = set()
        self.x_dim = (0,0)
        self.y_dim = (0,0)
        self.z_dim = (0,0)

    def read_init(self, init_map):
        for i,row in enumerate(init_map):
            for j,symb in enumerate(row):
                self[i,j,0] = symb
        return self

    def __setitem__(self, coord, value):
        # Only store the active coordinates
        if value != '#': return
        self.active.add(coord)
        self.x_dim = expand_dim(coord[0], self.x_dim)
        self.y_dim = expand_dim(coord[1], self.y_dim)
        self.z_dim = expand_dim(coord[2], self.z_dim)
    
    def __getitem__(self, coord):
        # Fake infinite space
        return '#' if coord in self.active else '.'

    def __len__(self):
        # The number of active locations in the map
        return len(self.active)

    def neighbours(self, x, y, z):
        # The number of active neighbours is the number of coordinates
        # we store in the neighbourhood.
        return sum( ((x+i,y+j,z+k) in self.active) for i,j,k in _NEIGHBOURS )
```

The map also keeps track of the range of coordinates in each dimension, where it stores active values. We use these when we compute a new map.

When we compute an updated map, we don’t have to consider coordinates more than one element away from the closest active cell. If we are more than one away, we are surrounded by inactive cells, and then we can only generate inactive cells—and we don’t have to worry about those, they are already implicitly there. So when computing the next map, we expand the coordinates in the old map by one in each direction, and then we iterate over all coordinates in the box that this gives us.

```python
def rule(pos, no_occ):
    if pos == '#': return '#' if no_occ in [2,3] else '.'
    else:          return '#' if no_occ == 3 else '.'

def grow_dim(dim):
    return (dim[0] - 1, dim[1] + 1)

def next_map(old_map):
    new_map = Map()
    x0,x1 = grow_dim(old_map.x_dim)
    y0,y1 = grow_dim(old_map.y_dim)
    z0,z1 = grow_dim(old_map.z_dim)
    for x, y, z in product(range(x0,x1), range(y0,y1), range(z0,z1)):
        new_map[x,y,z] = rule(old_map[x,y,z], old_map.neighbours(x,y,z))
    return new_map
```

We can be smarter here, and instead iterate through the neighbours of the active coordinates we have, applying the rule there instead. This isn’t what I did with my first solution, but it isn’t hard to do. It could look like this:

```python
def next_map(old_map):
    new_map = Map()
    for ax,ay,az in old_map.active:
        for x,y,z in ((ax+i,ay+j,az+k) for i,j,k in _NEIGHBOURS):
            new_map[x,y,z] = rule(old_map[x,y,z], old_map.neighbours(x,y,z))
    return new_map
```

On my input data, it was slower than just running through the entire box, but that might change depending on how the system evolves.

Evolving the map for a number of iterations is trivial with the code we have above, so answering the puzzle is equally trivial now:

```python
def evolve(m, n):
    for _ in range(n):
        m = next_map(m)
    return m

f = open('/Users/mailund/Projects/adventofcode/2020/17/input.txt')
init_map = f.read().split()
m = Map().read_init(init_map)
print(f"Puzzle #1: {len(evolve(m, 6))}")
```

Puzzle #2 is exactly the same, except that you add one extra dimension. Everywhere that you have `x,y,z` in the code above, you have `x,y,z,w`, and you keep track of the `w` dimension the same way as you keep track of the other dimensions. I will not list the code here, because it really is just a repeat.

