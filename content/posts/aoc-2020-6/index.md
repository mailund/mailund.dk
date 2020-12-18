+++
title = "Advent of Code 2020 — days 17-18"
date = 2020-12-18T08:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

Well, today, my blogging catches up with my [Advent of Code](https://adventofcode.com/) hacking. Just in time to fall behind again in the weekend. If that happens, I should be able to write up my weekend solutions on Monday. I don’t think I have that much work waiting for me then.

Anyway, to catch up, I need to get through yesterday’s and today’s puzzles. Yesterday was fun; today, it was mostly frustrating, because I tried to do something quick that ended up taking much longer than if I had just done it the right way, to begin with. Surprisingly how often things work out that way…


## Day 17 — Conway Cubes

On [Day 17](https://adventofcode.com/2020/day/17) we return to [Conway’s Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life). We saw it last on [day 11](https://mailund.dk/posts/aoc-2020-3/), where we evaluated maps according to local rules. Now, we have to do the same thing again, but this time, the map we evaluate is infinite!

How do we represent an infinite map? The obvious answer is that we don’t represent all coordinates explicitly. We start out with infinitely many inactive coordinates and a finite set of active coordinates. The rule for changing the map can only make finitely many active coordinates because it needs active coordinates to create one. This tells us that in finitely many steps, we can only have finitely many active coordinates. If we keep track of the coordinates that are active only, then we have a finite representation of a map.

I wrapped up this idea in a class, `Map`, that pretends to be a table—it implements `__getitem__()` and `__setitem__()`, but it never inserts inactive coordinates, and under the hood, it uses a set of active coordinates to represent the state. Otherwise, it closely resembles the code from day 6 in how it works.

```python
from itertools import product
_NEIGHBOUR_OFFSETS = (-1,0,1)
_NEIGHBOURS = [(i,j,k)
               for i,j,k in product(*([_NEIGHBOUR_OFFSETS] * 3)) 
               if (i,j,k) != (0,0,0)]

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
        return sum( ((x+i,y+j,z+k) in self.active) 
                    for i,j,k in _NEIGHBOURS )
```

The map also keeps track of the range of coordinates in each dimension, where it stores active values. We use these when we compute a new map.

When we compute an updated map, we don’t have to consider coordinates more than one element away from the closest active cell. If we are more than one away, we are surrounded by inactive cells, and then we can only generate inactive cells—and we don’t have to worry about those, they are already implicitly there. So when computing the next map, we expand the coordinates in the old map by one in each direction, and then we iterate over all coordinates in the box that this gives us.

```python
def rule(pos, no_act):
    if pos == '#': return '#' if no_act in [2,3] else '.'
    else:          return '#' if no_act == 3 else '.'

def grow_dim(dim):
    return (dim[0] - 1, dim[1] + 1)

def next_map(old_map):
    new_map = Map()
    x0,x1 = grow_dim(old_map.x_dim)
    y0,y1 = grow_dim(old_map.y_dim)
    z0,z1 = grow_dim(old_map.z_dim)
    for x, y, z in product(range(x0,x1), range(y0,y1), range(z0,z1)):
        new_map[x,y,z] = rule(old_map[x,y,z],
                              old_map.neighbours(x,y,z))
    return new_map
```

We can be smarter here, and instead iterate through the neighbours of the active coordinates we have, applying the rule there instead. This isn’t what I did with my first solution, but it isn’t hard to do. It could look like this:

```python
def next_map(old_map):
    new_map = Map()
    for ax,ay,az in old_map.active:
        for x,y,z in ((ax+i,ay+j,az+k) for i,j,k in _NEIGHBOURS):
            new_map[x,y,z] = rule(old_map[x,y,z],
                                  old_map.neighbours(x,y,z))
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

## Day 18 — Operation Order

Today, [day 18](https://adventofcode.com/2020/day/18), we have to do [new math](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwiGurfB_tbtAhUKmIsKHR1OAAUQyCkwAHoECAIQAw&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DUIKGV2cTgqA&usg=AOvVaw3jVIdCqtpsS5Vv2uTSmZY9). Well, what we have to do is evaluate expressions with addition, multiplication, and parentheses. For Puzzle #1, there is no precedence, and you have to evaluate them left-to-right, and in Puzzle #1, addition gets higher precedence than multiplication. Otherwise, you could, of course, paste them into any calculator and get the results this way…

Parsing and evaluating expressions is something I have done many times, and only a few weeks ago, we had exercises in my class about it, so I felt confident. However, I was overconfident. I know the “Right Way” to do it, but this is a quick exercise, so I felt confident that I could cut a few corners. I was wrong, and I spent an hour debugging when I had to fix the hack from Puzzle #1 to solve Puzzle #2. I will only show the solution for Puzzle #2 here (as both puzzles are a specialisation of the general approach that I should have taken in the first place).

With expressions like these, you can write a parser, and a recursive descent parser would be simple to do. However, we are only going to match parentheses, so scanning through expressions and using an explicit stack is probably easier, and that is what I did. Not exactly like this—as I said, I did mess up when trying to cut some corners—but it is what I ended up with, and it isn’t far from what I *attempted* to do, to begin with.

Here is the idea: you have a stack where you store partially evaluated expressions. Those you cannot evaluate yet, because you don’t have complete information. That would be all left-hand-sides of expressions where you do not have the right-hand-side yet. What you cannot handle yet, you put on the stack, and when you can evaluate an expression, you do so and update the stack.

The only tricky part here, and it isn’t that tricky if you take the time to think it through before you start programming—yeah, you can hear that I am blaming myself a lot today—is to work out when you should evaluate expressions on the stack. In my first attempt, I evaluated when I saw operands, but for Puzzle #2 it is easier when you have a new operator.

In the solution below, I put operands and operators on the stack when I see them, but before I put another operator on the stack, I will evaluate the top of the stack. That means we evaluate left-to-right, as we are supposed to in Puzzle #1. When I evaluate, I know the operator precedence of the next operator, because I have it in my hand when I call the evaluation, so I can make sure that I only evaluate expressions with higher binding.

For example, let us say I have the expression `1 + 3 * 4`. Then I first put 1 on the stack, so I have `[1]`. Then I see the operator, `+`, and I evaluate the top of the stack, which doesn’t do anything because we only have a single value there, but that value is the result. After evaluating the left-hand-side of `+`, I push the operator, and my stack is now `[1, +]`. Then I get the right-hand-side, 3, and push that onto the stack, which becomes `[1, +, 3]`. Then we see the operator `*`, which means that we should evaluate its left-hand-side. This is where precedence is used. If `*` binds tighter than `+`, as it usually does, then we cannot evaluate past `+` on the stack. The left-hand-side of the multiplication is 3 and not (1+3). So when evaluating the stack, we run down until we see + and then stop. If we give `+` higher precedence, then we should evaluate the addition, and then we evaluate the entire stack, leaving the value 4 there, which after we put `*` on there as well makes the stack `[4, *]`.

If we evaluate left-to-right, not considering operator binding, then the stack would be this during the evaluation:

```
[]        =>
[1]       =>
[1, +]    =>
[1, +, 3] => (and now evaluate when we see *)
[4, *]    =>
[4, *, 4] => (and now evaluate for the final result)
[16]
```

If addition binds tighter than multiplication, as in Puzzle #2, you have the same evaluation. If multiplication binds tighter, we do not evaluate past the plus when we evaluate for `*`, and then the evaluation would be

```
[]              =>
[1]             =>
[1, +]          =>
[1, +, 3]       => (with * we do not evaluate past +)
[1, +, 3, *]    =>
[1, +, 3, *, 4] => (with * we do not evaluate past +)
[1, +, 3, *, 4] => (and now evaluate for the final result)
[13]
```

The stack evaluation is fairly straightforward (when you do it this way and don’t try to be smart—I am still cursing myself). 

```python
from operator import add, mul
op_tbl = {'+': add, '*': mul}

def eval_stack(stack, precedence):
    rhs = stack.pop()
    while stack:
        if precedence_table[stack[-1]] > precedence:
            break
        op = stack.pop()
        lhs = stack.pop()
        rhs = op_tbl[op](lhs,rhs)
    stack.append(rhs)
```

I use a table to evaluate operations; that is the easiest way to do it, I think. I use another table to set precedence levels, and the evaluation stops if we run into an operation with higher precedence. I might have gotten the order of this wrong; we don’t go past something that binds looser than the operator we use right now, so maybe it would be better to change the order and the comparison, but you can multiply everything by minus one yourself. I have already spent more time on this than I want to.

We also need to handle parentheses, but the precedence table can handle that as well (and it was trying to handle parentheses in a different way that tripped me up). If we set the precedence of a left-parenthesis high, we won’t evaluate it past it. If we set the precedence of right-parentheses higher than the operators, but lower than the left-parenthesis, then evaluating with we see `)` will evaluate all the way down to the matching `(`.

I would love to say that there are no special cases with parentheses, but we still have to treat them differently than operators. That is because the grammar for expressions treat them differently. The binary operators always have operands on the left and right, but left parentheses can either have the beginning of the expression on the left, or have an operator, and right parentheses can have the end of the expression on the right, or have operators. So the state of the stack is different when we encounter parentheses. When we see a ‘(‘, we cannot evaluate the stack, because we might have an operator on the top and not a number. So in the evaluation function, I handle the four different symbols separately—well, I treat `+` and `*` the same, but `(` and `)` I handle in separate if-branches.

When I see a `(`, I put it on the stack. When I see an operator, I evaluate and then push the operator. When I see a `)`, I evaluate. Then I remove the corresponding left parenthesis afterwards.

When I am through scanning the expression, I evaluate the full stack. It could be a complete expression, but only partially evaluated. We don’t evaluate until we see an operator or a right parenthesis, so if we scan through `2 + 2`, the stack would be `[2, +, 2]`, and we need to do the final evaluation. I do that with the highest precedence that I can think of, which happened to be 1234.

The full solution looks like this:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/18/input.txt')
expressions = [expr.replace(" ","")
               for expr in f.read().strip().split('\n')]

from operator import add, mul
op_tbl = {'+': add, '*': mul}

def eval_stack(stack, precedence):
    rhs = stack.pop()
    while stack:
        if precedence_table[stack[-1]] > precedence:
            break
        op = stack.pop()
        lhs = stack.pop()
        rhs = op_tbl[op](lhs,rhs)
    stack.append(rhs)

def eval_expr(expr):
    stack = []
    # The numbers are single digits, so we can
    # look at individual characters--no lexer needed
    for tok in expr:
        if tok == '(':
            stack.append(tok)
        elif tok in '+*':
            eval_stack(stack, precedence_table[tok])
            stack.append(tok)
        elif tok == ')':
            eval_stack(stack, precedence_table[')'])
            stack.pop(-2) # get rid of '('
        else:
            stack.append(int(tok))

    # End of expression
    eval_stack(stack, 1234) # 1234 is just max precedence
    return stack[-1]

precedence_table = { '+': 0, '*': 0, ')': 2, '(': 3 }
print(f"Puzzle #1: {sum( eval_expr(expr) for expr in expressions )}")
precedence_table = { '+': 0, '*': 1, ')': 2, '(': 3 }
print(f"Puzzle #2: {sum( eval_expr(expr) for expr in expressions )}")
```


