+++
title = "Advent of Code 2020 — days 23 and 24"
date = 2020-12-24T07:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

Unexpectedly, I was allowed to play today—it *is* Christmas, after all—as long as I didn’t spend too much time at the computer. So I hurried up and solved today’s and yesterday’s puzzles quickly.

## Day 23 — Crab Cups

On [Day 23](https://adventofcode.com/2020/day/23), we get another game. It is a game of shuffling cups around, and it reads very much like a circular list of cups. And mostly it is.

You have to take three cups to the right of the current and move it to elsewhere in your circular list, based on the index of the current cup. The rules are not that hard to decode, and you can implement the solution using Python’s lists and a little bit of modular arithmetic.

```python
inp = "389125467" # test data
cups = list(map(int, inp))
min_cup = min(cups)
max_cup = max(cups)
n = len(cups)

def next_three(i):
    return [ (i+k) % n for k in range(1,4) ]

# Brute force with small list manipulations...
def round(cups, i):
    current_cup = cups[i]
    removed = [cups[i] for i in next_three(i)]
    remaining = [c for c in cups if c not in removed]
    
    destination = current_cup - 1
    while destination not in remaining:
        destination -= 1
        if destination < min_cup:
            destination = max_cup
    
    j = remaining.index(destination)
    remaining[j+1:j+1] = removed
    return remaining, (remaining.index(current_cup) + 1) % n

def play(cups, rounds):
    i = 0
    for _ in range(rounds):
        cups, i = round(cups, i)
    return cups

def rotation(cups, start):
    i = cups.index(start)
    return ''.join(str(cups[ (i+j+1) % n ]) for j in range(n))[:-1]

print(f"Puzzle #1: {rotation(play(cups[:], 100), 1)}")
```

When it comes to lists, linked lists and Python’s lists (which are arrays for all practical purposes), there are different performance tradeoffs. There always is with different data structures.

Linked lists will let us move a sub-list to another location in constant time (if we can extract the list in constant time, which we can here), but with arrays, we must copy the entire list to achieve this. Copying everything sounds slow, but it isn’t for small data sizes. Arrays sit in contiguous memory, and modern computer’s caches are really good at dealing with things like that. Add to this, that a linked list implemented in Python is bound to be much slower than Python’s own lists implemented in C. So for small data, slicing and composing the built-in lists is usually faster than rolling out a linked list.

For Puzzle #2, however, the size of the problem grows to a list of length one million, and we need to run ten million iterations of the game. Here, we enter a size where slow linked lists will outperform arrays for certain. 

The solution above will run in time \\( O(mn) \\) where \\( m \\) is the number of rounds and \\( n \\) is the size of the list. This is far too slow if \\(m\\) is ten million and \\(n\\) is a million. With linked lists, we can make each iteration take constant time, and go down to \\(m\\), which is more manable.

To get there, we need to represent the cups in a circular linked list, and to get the destination, we need a constant time approach to get the destination from its number. If we have that, then we have a solution to the puzzle.

So, I implemented a cyclic doubly-linked list:

```python
class Link(object):
    def __init__(self, val, prev = None, next = None):
        self.val = val
        self.prev = prev
        self.next = next

        if self.prev is not None:
            self.prev.next = self
        else:
            self.prev = self # circular list
        if self.next is not None:
            self.next.prev = self
        else:
            self.next = self # circular list

    def __contains__(self, val):
        link = self
        while True:
            if link.val == val: return True
            link = link.next
            if link is self: return False

    def __str__(self):
        links = [f"{self.val}"]
        link = self.next
        while link != self:
            links.append(f"{link.val}")
            link = link.next
        return " -> ".join(links)
```

Write a function for creating a linked list from a Python list, solely for convenience:

```python
def make_linked_list(x):
    link = Link(x[0])
    link.next = link.prev = link
    for y in x[1:]:
        Link(y, link.prev, link) # appending
    return link
```

And then I wrote functions for moving the three cups in the game:

```python
def take_three(link):
    start = link.next
    end = start.next.next
    start.prev.next = end.next
    end.next.prev = start.prev
    # make circular
    start.prev = end
    end.next = start
    return start

def insert_after(link, lst):
    lst.prev.next = link.next
    lst.prev.next.prev = lst.prev
    link.next = lst ; lst.prev = link
```

Playing the game in Puzzle #2 works the same way as in Puzzle #1, but first we build the linked list, and we create a map from cup names to links, so we can get the destination cup in constant time.

```python
min_cup = 1
max_cup = 1_000_000
def dec(i):
    return (i - 1) if (i - 1) >= min_cup else max_cup

def play(starting_cups):
    
    # Fill the cups to the max
    for i in range(10, max_cup + 1):
        Link(i, starting_cups.prev, starting_cups)

    # starting cup
    cup = starting_cups

    # Build dict to map from index to link
    LINK_MAP = {}
    LINK_MAP[cup.val] = cup
    link = cup.next
    while link != cup:
        LINK_MAP[link.val] = link
        link = link.next

    # Now play the game...
    for i in range(10_000_000):
        removed = take_three(cup)
        dest = dec(cup.val)
        while dest in removed:
            dest = dec(dest)
        insert_after(LINK_MAP[dest], removed)
        cup = cup.next

    return LINK_MAP[1].next.val * LINK_MAP[1].next.next.val

inp = "389125467" # test data
cups = make_linked_list(list(map(int, inp)))
print(f"Puzzle #2: {play(cups)}")
```

The lists are doubly-linked, but they do not have to be. It makes it easier to insert one list into another, because the first link in a list also contains a pointer to the last, but since we only move lists of length three, we could hardwire it and save a little space.

I reached for doubly-linked lists right away, because the problem screams for them, and I knew I could solve it that way. But it is actually overkill. We can easily handle the the problem without a new class. After all, the only thing we need to make the algorithm fast is an indirect way to handle the “next” relationship. And an array will work just fine for that.

We can add another array to our data, where index \\(i\\) gives us the index of the cup clockwise from the cup with index \\(i\\), i.e., if the cup at index \\(i\\) has the cup with index \\(j\\) to its right, then `next[i] == j`. That is all we need to make it work.

This is easiest to do if all the indices up to the length of the array is in use, so I subtracted one from all the cup identifiers. They start at one and go to one million, but now they start at zero and go to 999,999. At the end, I have to get the two cups following cup zero instead of one, and I need to add one to their values before I multiply them. I still need a map from cup ids to indices, because the first ten are out of order, but I *only* need a map for the first ten indices. After that, each cup identity is also its index.

There is a little bit of bookkeeping to look up the next cup—you need to get the cup index and then the value in the `next` array—but it is nothing worse than we have seen many times before in our lives.

This approach gives us code like this:

```python
min_cup = 1
max_cup = 1_000_000

def play(starting_cups):
    # Zero-index instead
    starting_cups = [x - 1 for x in starting_cups]
    cups = starting_cups + list(range(max(starting_cups) + 1, max_cup))
    
    LINK_MAP = { starting_cups[i]: i for i in range(len(starting_cups)) }
    def cup_idx(i): return LINK_MAP[i] if i in LINK_MAP else i
    
    next_links = cups[1:] + [cups[0]]
    def next_cup(cup):
        return next_links[cup_idx(cup)]
    def set_next(cup, n):
        next_links[cup_idx(cup)] = n
    
    # starting cup
    cup = cups[0]

    # Now play the game...
    for i in range(10_000_000):
        a = next_cup(cup)
        b = next_cup(a)
        c = next_cup(b)

        dest = cup
        while dest in [cup, a, b, c]:
            dest -= 1
            if dest < 0: dest = max_cup - 1

        set_next(cup, next_cup(c)) # cup's next is past the three
        set_next(c, next_cup(dest))
        set_next(dest, a)
        
        cup = next_cup(cup)

    return (1 + next_cup(0)) * (1 + next_cup(next_cup(0)))
```

## Day 24 — Lobby Layout

[On the 24th](https://adventofcode.com/2020/day/24), we get to play with hexagonal floor tiles. There is not much to those, except that you have to be a little careful with coordinates. If you move to a tile next to you, you have moved twice as far as if you go to the tile to the upper right of you. But other than that, you can think of tiles as their coordinates. If the center of a floor os (0,0), you can encode the tile to the right of you as (1,0) the one to your left as (-1,0), the one to the north-east as (1/2,1/2), the one to the south-east as (1/2,-1/2), and so on. Or, if you don’t like using floating point numbers, use (0,0) for the center, (2,0) for the tile to the East, (-2,0) for the tile to the West,  (-1,1) and (1,1) for the tiles above you, and (-1,-1) and (1,-1) for the tiles below you.

That is what I did, except that I used complex numbers. I figured that we might be in for a Puzzle #2 where we needed rotations or something, and complex numbers are easier there. I think something like that was going through my brain. But it doesn’t matter, I can use complex numbers as 2D vectors if I want to, and that was all I needed.

That being said, if this was code that should survive longer than this puzzle, I would change it back now. It is confusing to use complex numbers in this context.

Anyway, for Puzzle #1, we need to work out how many tiles have flipped to black from a path to the tiles. Decoding the path is straightforward. Keep an index into the string you are parsing, and if it points to a `n` or `s`, you are looking at half of a direction, and you have to go up or down (`1j` or `-1j`). After that, we work out how far to the left or right we need to go. If we don’t go up and down, the direction to the East or West should be a distance of 2, but if we go up or down, it should be a distance of 1, so I correct that when I see `n` or `s`. Otherwise, there is really nothing to it.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/24/input.txt')
tiles = f.read().strip().split()

def identify_tile(x):
    i, tile = 0, 0 + 0j
    while i < len(x):
        ew_step = 2
        if x[i] == 'n':
            tile += 1j
            i += 1
            ew_step = 1
        elif x[i] == 's':
            tile -= 1j
            i += 1
            ew_step = 1

        if x[i] == 'e':
            tile += ew_step
            i += 1
        else:
            assert x[i] == 'w'
            tile -= ew_step
            i += 1

    return tile
```

When we have all the tile positions, we insert or remove them from a set of black tiles, and the size of the set when we are done is the answer to Puzzle #1:

```python
def collect_black(tiles):
    black_tiles = set()
    for x in tiles:
        tile = identify_tile(x)
        if tile in black_tiles:
            black_tiles.remove(tile)
        else:
            black_tiles.add(tile)
    return black_tiles

print(f"Puzzle #1: {len(collect_black(tiles))}")
```


For Puzzle #2, we have a Game of Life-like puzzle, and we have seen many of those already. It is, in principle, on an infinite floor, so we can use the trick we used on [Day 17](https://mailund.dk/posts/aoc-2020-6/), of only keeping track of the tiles we need for the rules. We need to update tiles based on their black neighbours, so we can store the coordinate of black tiles only. When we need to update the floor, we iterate through the black tiles and their neighbours, and those are the only coordinates that might change into or remain black.

I wrote a class for that, although it wouldn’t have been harder to work with a set direction to be honest.

```python
NEIGHBOURS = [ 1+1j, 2, 1-1j, -1-1j, -2, -1+1j ]
class Floor(object):
    def __init__(self, tiles = ()):
        self.blacks = collect_black(tiles)

    def black_neighbours(self, tile):
        return sum( (tile + n) in self.blacks for n in NEIGHBOURS )

    def __iter__(self):
        for tile in self.blacks:
            yield 'B', tile, self.black_neighbours(tile)
            for n in NEIGHBOURS:
                if tile + n not in self.blacks:
                    yield 'W', tile + n, \
                          self.black_neighbours(tile + n)

    def next_floor(self):
        floor = Floor()
        for col, coord, black_n in self:
            if col == 'W' and black_n == 2:
                floor.blacks.add(coord)
            elif col == 'B' and 1 <= black_n <= 2:
                floor.blacks.add(coord)
        return floor

    def __len__(self): return len(self.blacks)
```

Evolving the floor works exactly as the other Game of Life puzzles this year, so nothing new here either:

```python
floor = Floor(tiles)
def evolve(tiles, days):
    floor = Floor(tiles)
    for _ in range(days):
        floor = floor.next_floor()
    return floor

print(f"Puzzle #2: {len(evolve(tiles, 100))}")
```

So all in all, this was a very easy day. Maybe, if I am lucky, I am allowed to play tomorrow again, and if it is just as simple, I will finish the puzzles on time.



