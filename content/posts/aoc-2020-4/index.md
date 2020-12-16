+++
title = "Advent of Code 2020 — days 12-14"
date = 2020-12-16T10:04:39+01:00
draft = true
tags = ["python", "programming"]
categories = ["Programming"]
+++



## Day 12 —

```python
from math import cos, sin, pi
class Position(object):
    def __init__(self):
        self.x = 0.0
        self.y = 0.0
        self.angle = 0.0 # facing east

    @property
    def manhattan_dist(self):
        return abs(self.x) + abs(self.y)

    # Ops...
    def N(self, amount): self.y += amount
    def S(self, amount): self.y -= amount
    def E(self, amount): self.x += amount
    def W(self, amount): self.x -= amount
    def L(self, angle):  self.angle += pi * angle / 180.0 # use radiants
    def R(self, angle):  self.L(-angle) # subtraction, because we turn right...
    def F(self, amount):
        self.x += amount * cos(self.angle)
        self.y += amount * sin(self.angle)

pos = Position()
dispatcher = {op: getattr(pos, op) for op in "NSEWLRF"}

f = open('/Users/mailund/Projects/adventofcode/2020/12/input.txt')
for op in [line.strip() for line in f]:
    dispatcher[op[0]](int(op[1:]))
print(f"Puzzle #1: {int(pos.manhattan_dist)}")
```

```python
from math import cos, sin, pi
class Waypoint(object):
    def __init__(self):
        self.x = 10.0
        self.y = 1.0

    # Ops...
    def N(self, amount): self.y += amount
    def S(self, amount): self.y -= amount
    def E(self, amount): self.x += amount
    def W(self, amount): self.x -= amount
    def rotate(self, angle):
        angle = pi * angle / 180.0 # use radiants
        self.x, self.y = self.x * cos(angle) - self.y * sin(angle), \
                         self.x * sin(angle) + self.y * cos(angle)

class Ship(object):
    def __init__(self):
        self.waypoint = Waypoint()
        for op in "NSEW": setattr(self, op, getattr(self.waypoint, op))
        self.x = 0.0
        self.y = 0.0

    @property
    def manhattan_dist(self):
        return abs(self.x) + abs(self.y)

    # Ops...
    def L(self, angle):  self.waypoint.rotate(angle)
    def R(self, angle):  self.waypoint.rotate(-angle)
    def F(self, amount):
        self.x += amount * self.waypoint.x
        self.y += amount * self.waypoint.y
        print('F', self.x, self.y)

ship = Ship()
dispatcher = {op: getattr(ship, op) for op in "NSEWLRF"}

f = open('/Users/mailund/Projects/adventofcode/2020/12/input.txt')
for op in [line.strip() for line in f]:
    dispatcher[op[0]](int(op[1:]))
print(f"Puzzle #2: {round(ship.manhattan_dist)}")
```

```python

class Ship(object):
    def __init__(self):
        self.wp  = 10 + 1j
        self.pos =  0 + 0j

    @property
    def manhattan_dist(self):
        return abs(self.pos.real) + abs(self.pos.imag)

    # Ops...
    def N(self, amount): self.wp += amount*1j
    def S(self, amount): self.wp -= amount*1j
    def E(self, amount): self.wp += amount
    def W(self, amount): self.wp -= amount
    def L(self, angle):  self.wp *= 1j ** (angle // 90)
    def R(self, angle):  self.wp *= 1j ** (-angle // 90)
    def F(self, amount): self.pos += amount * self.wp

ship = Ship()
dispatcher = {op: getattr(ship, op) for op in "NSEWLRF"}

f = open('/Users/mailund/Projects/adventofcode/2020/12/input.txt')
for op in [line.strip() for line in f]:
    dispatcher[op[0]](int(op[1:]))
print(f"Puzzle #2: {round(ship.manhattan_dist)}")
```

