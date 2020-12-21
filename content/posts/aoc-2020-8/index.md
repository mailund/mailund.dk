+++
title = "Advent of Code 2020 — days 20 and 21"
date = 2020-12-21T07:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

## Day 20: Jurassic Jigsaw

[Day 20](https://adventofcode.com/2020/day/20) we get tiles for a puzzle, and we have to work out the puzzle from them. The tiles can be rotated or flipped, but we can connect them by identifying how edges match.

Puzzle #1 is fairly straightforward. In my first attempt, I tracked both which edges connected to other tiles and whether they matched in reverse, but it became a book-keeping nightmare in Puzzle #2, so I gave up on that. Instead, I just match all edges and all pairs of tiles, both directly comparing the edges and comparing with one reversed, and collected how tiles are matched. There are no cases in my input where one edge matches more than one tile, which was nice to see, as that could be important.

For Puzzle #1, we only need to identify the corners of the puzzle, and those are the tiles with only two connections. I used the `Tile` class below to keep track of that. I didn’t add the rotations and flipping until Puzzle #2, but I am not going to remove the functionality just to show you a clean implementation here. I have already spent too much time on the puzzle today. The key aspect of the class is that we keep track of the image and the borders (that we automatically update when we modify it in Puzzle #2), and we will have a dictionary, `connections` that map borders to tiles that can match that border.


```python
def keyflip(f, d):
    return { f(k): v for k,v in d.items() }
def ewflip(x):
    if x == 'E': return 'W'
    if x == 'W': return 'E'
    else:        return x
def nsflip(x):
    if x == 'N': return 'S'
    if x == 'S': return 'N'
    else:        return x

class Tile(object):
    def __init__(self, tile_id, pixels):
        self.tile_id = tile_id
        self.pixels = pixels
        self.connections = {}

    # Border edges, north, east, south, west
    @property
    def N(self): return self.pixels[0]
    @property
    def E(self): return ''.join(line[-1] for line in self.pixels)
    @property
    def S(self): return self.pixels[-1]
    @property
    def W(self): return ''.join(line[0] for line in self.pixels)
    @property
    def edges(self): return ( (e,getattr(self,e)) for e in "NESW" )

    def connect(self, ori, other):
        # In the general case, the same edge can match more than
        # one other tile. That makes the problem harder, but
        # here we check that it doesn't happen in our input
        assert ori not in self.connections
        self.connections[ori] = other

    def rot(self, a, b):
        x = "NESW"
        r = x.index(a) - x.index(b)
        if r < 0: r += 4

        for _ in range(r): # FIXME: be smarter, Thomas
            self.pixels = [ *zip(*self.pixels[::-1]) ]
        self.pixels = [ ''.join(x) for x in self.pixels ]

        self.connections = {
            x[(i + r) % 4]: self.connections[x[i]]
            for i in range(4) 
            if x[i] in self.connections
        }

    def flip_horizontal(self):
        self.connections = keyflip(ewflip, self.connections)
        self.pixels = [ x[::-1] for x in self.pixels ]

    def flip_vertical(self):
        self.connections = keyflip(nsflip, self.connections)
        self.pixels = self.pixels[::-1]

    def __str__(self):
        return "\n".join(
            [f"{self.tile_id}", *self.pixels]
        )
    def __repr__(self):
        return f"tile {self.tile_id}"
```

Parsing the data is ugly, but there is nothing much to it:

```python
# Parse the tiles...
import re
def parse_tiles(fname):
    with open(fname) as f:
        tiles = []
        for tile in f.read().strip().split('\n\n'):
            tile = tile.split('\n')
            tile_id, = re.match(r"Tile (\d+):",tile[0]).groups()
            tiles.append(Tile(int(tile_id), tile[1:]))
        return tiles
```

To work out which tile can connect to which other tiles, there is nothing clever you can do, I think. You have to compare them to figure out if a match on a border is possible. (Unless you start making data structures of borders you can work in—I suppose that is also an option, but this \\( O(n^2) \\) part of the puzzle is not that slow, so I wouldn’t bother with it when we have so few tiles as we do. In any case, the problematic part with my implementation isn’t the matching, but the assumption that each edge can at most match one other tile. That is guaranteed to be false in a real problem, but dealing with it will be much much harder. So this bit of code suffices here:

```python
# Connect the tiles...
def connect_tiles(tiles):
    def connect(x, y):
        for ori_x, edge_x in x.edges:
            for ori_y, edge_y in y.edges:
                if edge_x == edge_y or edge_x == edge_y[::-1]:
                    x.connect(ori_x, y)
                    y.connect(ori_y, x)

    for i in range(len(tiles)):
        for j in range(i + 1, len(tiles)):
            connect(tiles[i], tiles[j])

    return tiles
```

At this point, all tiles know which neighbours they can match. A tile in the middle of the puzzle will have four neighbours, those on edges will have three, and the corners will have two. That makes it easy to extract the corners:

```python
# Puzzle #1: get the tiles with two (four with flip) neighbours
fname = '/Users/mailund/Projects/adventofcode/2020/20/input.txt'
import math
tiles = connect_tiles(parse_tiles(fname))
corners = [ tile for tile in tiles if len(tile.connections) == 2 ]
print(f"Puzzle #1: {math.prod(tile.tile_id for tile in corners )}")
```

For me, Puzzle #2 was rather unpleasant. The way I kept track of connections was more complicated than that above, which became such a mess that I gave up on debugging it. I deleted all the code and took a break. When I got back to it, I went for the simple solution you see above. I still fucked up with the `edges` property, so it didn’t compute the edges each time you asked for it, which naturally became a problem and one that was hard to debug. There when well over an hour. After that, I had to chase down a bug in rotations, when the rotations need to go counter-clockwise. Simple enough debugging, but when you are in a bit of a hurry because you really ought to be doing something else, you try to force the code, and that rarely works.

Anyway, I decided to build the puzzle from the upper left corner, scanning one row at a time. When I know the tile on the left of a tile, I know how to fix it with rotations and flips to make it match, and the same goes when I know the tile above me. So I can start from the upper left, fix towards the right (or eastwards in the code) until I can go no further. Then the first row is done, so I go back to the first tile in the row, get its southern neighbour, fix it if necessary, and then build the next row from it.

```python
def fix_east(west, east):
    ori = [k for k,v in east.connections.items() if v == west][0]
    east.rot('W', ori)
    if west.E != east.W:
        east.flip_vertical()
    assert west.E == east.W
    if 'N' in east.connections:
        assert east.N == east.connections['N'].S

def fix_south(north, south):
    ori = [k for k,v in south.connections.items() if v == north][0]
    south.rot('N', ori)
    if north.S != south.N:
        south.flip_horizontal()
    assert north.S == south.N
    
def tile_row(x):
    res = []
    while 'E' in x.connections:
        res.append(x)
        x = x.connections['E']
        fix_east(res[-1], x)
    res.append(x)
    return res

def assemble_tiles(tiles):
    x = [ # get upper left tile to start from
        tile for tile in tiles 
        if set(tile.connections.keys()) == {'E','S'} 
    ][0]

    res = []
    row = tile_row(x)
    while 'S' in row[0].connections:
        res.append(row)
        x = row[0].connections['S']
        fix_south(row[0], x)
        row = tile_row(x)
    res.append(row)
    return res

assembly = assemble_tiles(tiles)
```

Once you have assembled all the tiles, you might be able to scan for monsters directly in them, but for me, it was easier to build the image. That, at least, was easy to do:

```python
def remove_borders(tiles):
    for tile in tiles:
        tile.pixels = [ row[1:-1] for row in tile.pixels[1:-1] ]

remove_borders(tiles)

def insert_tile(img, tile, x, y):
    k = len(tile.pixels)
    for i in range(k):
        for j in range(k):
            img[k*x+i][k*y+j] = tile.pixels[i][j]

def build_img(assembly):
    n, m, k = len(assembly), len(assembly[0]), len(assembly[0][0].pixels)
    img = [ [' '] * (m*k) for _ in range(n*k) ]
    for x in range(n):
        for y in range(m):
            insert_tile(img, assembly[x][y], x, y)
    return img
```

To find the monsters, I use a sliding window approach. I don’t think that there are overlapping monsters—and the description didn’t tell us what to do if that happened—so I didn’t worry about it.

```python
MONSTER = \
"""                  # 
#    ##    ##    ###
 #  #  #  #  #  #   """.split('\n')
MONSTER_OFFSETS = [
    (i,j) for i in range(len(MONSTER))
          for j in range(len(MONSTER[0]))
          if MONSTER[i][j] == '#'
]

def detect_monster(img, x, y):
    return all(
        img[x + i][y + j] == '#'
        for i,j in MONSTER_OFFSETS
    )
def draw_monster(img, x, y):
    for i,j in MONSTER_OFFSETS:
        img[x + i][y + j] = 'O'

def scan_for_monsters(img):
    found = False
    n, m = len(img), len(img[0])
    nn, mm = len(MONSTER), len(MONSTER[0])
    for x in range(n - nn):
        for y in range(m - mm):
            if detect_monster(img, x, y):
                found = True
                draw_monster(img, x, y)
    return found
```

There might not be any monsters in the first image, but then we can try to rotate and flip. For my input, I found the monsters after rotating, so I didn’t implement flipping an image.

```python
# Try rotations until we find something or have rotated all the way
img = build_img(assembly)

def rotate_img(img):
    return [ *map(list, zip(*img[::-1])) ]

def print_img(img):
    print('\n'.join( ''.join(row) for row in img ))

for _ in range(4):
    if scan_for_monsters(img):
        break
    img = rotate_img(img)

# It was enough with rotations for me, but potentially
# you would need flips as well...
print(f"Puzzle #2: {sum(row.count('#') for row in img)}")
```

I admit that I didn’t have that much fun with this puzzle. It was mostly grunt work and not clever ideas. I know, I know, most programming *is* grunt work, but when I do that, I get paid to do it. When I program for fun, I want to have fun.

I still think I would have had more fun with it if I had known that it would take this long to solve, and I had set aside the necessary time, but I was rushing to finish, and that makes it stressful, and I mess up much more than I usually do (which is plenty, I might add).

I had thought about sneaking up to the computer during the holiday to solve the puzzles, but if they take more than an hour from now on, then I have to leave them for after New Year. I fully plan to get through, but I don’t want to hide in the office over the holiday. And I know very well, that once I start on a problem, I cannot put it down again until it is done. Even if it took all of Christmas Day, I would be working. That won’t do. So I have to make up my mind soon on whether I should finish this year, or leave the last few puzzles for January.

## Day 21 — Allergen Assessment

[Day 21](https://adventofcode.com/2020/day/21)  looked very scary to me at first. The way it is framed smells awfully much like we would have to implement a graph pairing algorithm, and I was sure I would be in for another long session of grunt work. Thankfully, it was a lot easier than I feared. With this day, we are back to about an hour, hour and a half, for solving both puzzles.

When I read the description, I was thinking bipartite graph, pairing or flow, or something like that, so I wrote up some code for handling that. Ingredients know which allergens they might contain, and allergens know which ingredients they might be in, and because Puzzle #1 wants us to check the recipes in the input, I made a class for that as well. I was *so* prepared for something hard.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/21/input.txt')

class IngredientsList(object):
    def __init__(self, foods, allergens):
        self.foods = foods
        self.allergens = allergens

class Food(object):
    def __init__(self, name):
        self.name = name
        self.may_contain = set()

    def add_allergens(self, allergens):
        self.may_contain.update(allergens)

class Allergen(object):
    def __init__(self, name):
        self.name = name
        self.might_be_in = None
    def add_foods(self, foods):
        if self.might_be_in is None:
            self.might_be_in = set(foods)
        else:
            self.might_be_in &= set(foods)
        
class Graph(object):
    def __init__(self):
        self.foods = {}
        self.allergens = {}
    def food(self, name):
        if name not in self.foods:
            self.foods[name] = Food(name)
        return self.foods[name]
    def allergen(self, name):
        if name not in self.allergens:
            self.allergens[name] = Allergen(name)
        return self.allergens[name]

GRAPH = Graph()
LIST = []

import re
for line in f:
    foods, allergens = \
	    re.match(r"([^\(]+) \(contains (.*)\)", line).groups()
    foods = foods.split()
    allergens = [a.strip() for a in allergens.strip().split(',')]

    for food in foods:
        GRAPH.food(food).add_allergens(
	        GRAPH.allergen(a) for a in allergens
	      )
    for allergen in allergens:
        GRAPH.allergen(allergen).add_foods(
	        GRAPH.food(f) for f in foods
	      )

    LIST.append(IngredientsList(
      [GRAPH.food(food) for food in foods],
      [GRAPH.allergen(a) for a in allergens]
    ))
```

However, Puzzle #1 is much like some of the earlier puzzles, where we can work out the answer with set operations. For each allergen, the input lines tell us a set of ingredients they might be in, and if we compute the intersections of those lists, we can eliminate ingredients they might be in. The description threw me a little when it said that there might be allergens left out, which throws the whole declaration up in the air, but when we know that at most one food item can have an allergen, it falls back into place.

So, I simply compute the intersection of food items for all the allergens over all the input lists. That is why I use the `&=` to update allergens’ relations to food items, while I do not do the same for the other direction. If I had know about Puzzle #2 before I wrote this code, I wouldn’t hade made the graph, and food ingredients would just be their names, so the code is completely over-engineered. After solving Day 20, however, I don’t have the strength to reimplement this one as well.

Anyway, if we have computed the intersections of the sets for all the allergens, the safe ingredients are those that are not in any of those sets. So, we can compute the union of the allergens’ sets, make a set of all the food items, and the set-difference gives us the safe food. After that, it is just counting.

```python
## PUZZLE #1 ---------------------------------------------
contains_allergens = set.union( 
	*(a.might_be_in for a in GRAPH.allergens.values())
)
foods = set(GRAPH.foods.values())
no_allergens = foods - contains_allergens
count = sum((food in lst.foods) 
            for food in no_allergens for lst in LIST)
print(f"Puzzle #1: {count}" )
```

I open Puzzle #2 with trembling hands, but ended up pleasantly surprised. We need to pair allergens with ingredients, and that is potentially a pairing algorithm. However, we are once again in the situation where we have some singletons to start from, and whenever we have a singleton to an allergen, we can make a pairing and remove the corresponding ingredient from the other sets. If we do this until there are only singletons left, we are done.

```python
## PUZZLE #2 ---------------------------------------------
def elimination(allergens):
    pairings = []
    while True:
        singletons = [
            a for a in allergens if len(a.might_be_in) == 1
        ]
        allergens = [
            a for a in allergens if len(a.might_be_in) > 1
        ]
        pairings.extend(singletons)

        if len(allergens) == 0:
            return pairings
        
        for s in singletons:
            food, = s.might_be_in
            for r in allergens:
                if food in r.might_be_in:
                    r.might_be_in.remove(food)

def danger_list(pairings):
    lst = sorted([
        (a.name,list(a.might_be_in)[0].name)
        for a  in pairings
    ])
    return ','.join(f for a,f in lst)

pairings = elimination(GRAPH.allergens.values())
cannonical_list = danger_list(pairings)
print(f"Puzzle #2: {cannonical_list}")
```

You cannot always do this, of course, and quite often it becomes an optimisation problem, and I was not in the mood for that, so I am very happy that this worked.

Day 21 was fun, so I will have a look at the puzzles tomorrow as well. The day after, my holiday begins, so I will leave the last three days’ puzzles to January, where I am home alone anyway. They will make a nice distraction between the Zoom-exams.

By January, I will also have time to fix up code before I post it—and it needs that if the two days in this post are indicators of what is to come.
