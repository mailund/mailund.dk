+++
title = "Advent of Code 2020 — days 12-13"
date = 2020-12-16T10:04:39+01:00
draft = true
tags = ["python", "programming"]
categories = ["Programming"]
+++

I don’t have a lot of time today, so I will only describe the solutions for two days. I promise that I will catch up to the day the puzzles are released, but it probably won’t be until after the weekend…

## Day 12 — Rain Risk

In [day 12](https://adventofcode.com/2020/day/12) we are navigating a ship—because why not?

We have another virtual machine. It isn’t described exactly like a virtual machine, so it might be less obvious than the machine in [day 8](https://mailund.dk/posts/aoc-2020-2/), but it is what we have. There is a state—the position and the angle we are facing—and there are instructions for modifying the state. So, without thinking too deeply about it, I did the same as in day 8: I made a class for the state, put the operations in it as methods, then made a table that maps from opcodes to actions, and ran the program.

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
    def L(self, angle):  self.angle += pi * angle / 180.0 # radiants
    def R(self, angle):  self.L(-angle) # subtraction bus R == -L
    def F(self, amount):
        self.x += amount * cos(self.angle)
        self.y += amount * sin(self.angle)

pos = Position()
dispatcher = {op: getattr(pos, op) for op in "NSEWLRF"}

f = open('/Users/mailund/Projects/adventofcode/2020/12/input.txt')
for op in [line.strip() for line in f]:
    dispatcher[op[0]](int(op[1:]))
```

After the program, we want the Manhattan distance for the position. I implemented that as a property, and I don’t really know why. I guess I just felt like it. A method would be fine, or you could even extract the coordinates and compute it directly when you answer the puzzle.

```python
print(f"Puzzle #1: {round(pos.manhattan_dist)}")
```

This was entirely standard code, following the same template as for day 8. (But I don’t plan on generating machine code for this one—once is enough). 

For Puzzle #2, we change the virtual machine. Now, the state is both the location of the ship and a waypoint, and some of the operations modify the waypoint, while others modify the ship.

I took the direct approach and refactored the code into a `Waypoint` and a `Ship` class, with a position in the waypoint and waypoint and position in the ship. I put the waypoint operations in that class, and the others in the ship, with a dispatch between ship and waypoint for the waypoint operations. That way, I can build the table for the operations the same way as before.


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

ship = Ship()
dispatcher = {op: getattr(ship, op) for op in "NSEWLRF"}

f = open('/Users/mailund/Projects/adventofcode/2020/12/input.txt')
for op in [line.strip() for line in f]:
    dispatcher[op[0]](int(op[1:]))
print(f"Puzzle #2: {round(ship.manhattan_dist)}")
```

The only tricky part was the trigonometry for changing the angle. I didn’t notice until later that all the changes are multiples of 90 degrees.

Since we are looking at multiples of 90 degrees, rotations are simpler. If you turn 90, you map \\( (x,y) \\) into \\( (-y,x) \\). Do it twice, and you turn 180 degrees, so you go \\( (x,y) \mapsto (-x,-y) \\). And 270 sends you to \\( (y,-x) \\). Take the angle you have to turn, divide it by 90, and apply this rule  that many times. Or make a table for the transformations. It is likely to be simpler and faster than the trigonometry, but I didn’t see that the angles were this regular, and if it was in the problem description I missed it. 

However, if you are simplifying the code, you can do better than building a table for the rotations. You can use complex numbers.

Both the waypoint and the ship contain a two-dimensional position, and when you look at a complex number the right way, that is what they are. We can use the real part for the x-coordinate and the imaginary part for the y-coordinate. When we move East/West, we add an amount to the real part; when we move North/South, we add an amount to the imaginary part. That simplifies the arithmetic.

What is more interesting is how complex numbers help us with the rotations. If you multiply complex numbers \\( x+iy \\) and \\( v + iw \\) you get \\( (xv-yw) + i(xw+yv) \\). That is just how multiplication is defined for these buggers. But it is interesting for us, because we can construct the transformations from above from this. If we take the imaginary number \\(i\\) and put raise it to increasing powers we get

$$i^0 = 1 +i0$$
$$i^1 = 0+i1$$
$$i^2 = -1+0i$$
$$i^3 = 0-1i$$

after which it cycles back to 1 again. Now take a point, \\( (x,y) \\) represented as a complex number, \\( z = x+iy \\), and multiply it with these powers.

$$ (x,y) \mapsto (x,y)\cdot i^0 = (x+iy)(1+i0) = x + iy = (x,y) $$
$$ (x,y) \mapsto (x,y)\cdot i^1 = (x+iy)(0+i1) = -y + ix = (-y,x) $$
$$ (x,y) \mapsto (x,y)\cdot i^2 = (x+iy)(-1+i0) = -x - iy = (-x,-y) $$
$$ (x,y) \mapsto (x,y)\cdot i^3 = (x+iy)(0-i1) = y - ix = (y,-x) $$

These are the transitions from above. So, if you want to rotate by 90 degrees, you multiply your coordinates (as a complex number) by \\( i^1 \\). If you want to rotate them more, in steps of 90 degrees, raise \\( i \\) to higher powers. With this trick, we can solve the puzzle like this:

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

In Python, the imaginary number is `j`. Well, if you have a number in front of `j` it is an imaginary number; `j` is just a variable name otherwise. But you create complex numbers using `j`. Mathematicians use \\(i\\) for imaginary numbers and electrical engineers use \\(j\\), and Python follows the latter convention. (I use the former here, except in code).

This implementation only handles angles that are multiples of 90 degrees, but we can generalise it. The trigonometry we used for rotations earlier can also be phrased in terms of complex numbers. The rotation worked by mapping \\( (x,y) \\) to \\( (x\cos\theta - y\sin\theta, x\sin\theta + y\cos\theta) \\) for angle \\(\theta\\). If we call \\( v=\cos\theta \\) and \\( w=\sin\theta \\), then that is \\( (xv - yw, xw + yv) \\) which is the product of complex numbers \\( x+iy \\) and \\( v+iw \\). So if we can translate an angle \\(\theta\\) into the number \\(\cos\theta + i\sin\theta\\), then we have a general rotation. And we can, because that is what exponentiation does to complex numbers.

If you take an angle \\(\theta\\) (in radiants), then \\(e^{i\theta} = \cos\theta + i\sin\theta\\). Thus, we can get a general ship implementation with complex numbers like this:

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
    def L(self, angle):  self.wp *= e ** (angle * pi/180 * 1j)
    def R(self, angle):  self.wp *= e ** (-angle * pi/180 * 1j)
    def F(self, amount): self.pos += amount * self.wp
```

## Day 13 — Shuttle Search

This is my least favourite task in Advent of Code 2020 so far. The title should be [Chinese remainder theorem](https://en.wikipedia.org/wiki/Chinese_remainder_theorem) instead, because the difficulty entirely depends on whether you know this result from number theory or not. But I am getting ahead of myself.

Read [the program description](https://adventofcode.com/2020/day/13). If you haven’t already solved Puzzle #1, then you can’t see the part that I was hinting at with CRT, so we will quickly get the first puzzle out of our way and then get to Puzzle #2, that is either trivial or unreasonably hard, depending on your background.

**FIXME**


```python
f = open('/Users/mailund/Projects/adventofcode/2020/13/input.txt')
depart = int(f.readline())
busses = [int(bus) for bus in f.read().strip().split(',') if bus != 'x']

# Puzzle #1: Get the earliest bus after departure...
waiting = sorted((b - depart % b, b) for b in busses)
w, b = waiting[0]
print(f"Puzzle #1: {b * w}")
```


```python
f = open('/Users/mailund/Projects/adventofcode/2020/13/input.txt')
depart = int(f.readline())
busses = [(offset, int(bus))
            for offset, bus in enumerate(f.read().strip().split(','))
            if bus != 'x']

from sympy.ntheory.modular import crt 
n = [b for o,b in busses]
a = [(b - o) for o,b in busses]
x, N = crt(n, a)
print(f"Puzzle #2: {x}")
```


