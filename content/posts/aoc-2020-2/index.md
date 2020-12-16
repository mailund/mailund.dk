+++
title = "Advent of Code 2020 — days 06–08"
date = 2020-12-15T06:48:38+01:00
draft = false
tags = ["python", "C", "R", "programming"]
categories = ["Programming"]
+++

Ok, now that today’s puzzles are solved, I can go back and look at solutions to the previous days. Today, I will show you my solutions for days six through eight. There is some fun stuff in these days, with graph algorithms, memorisation, and virtual machines, the latter which I found particularly fun to play with.

## Day 06 — Custom Customs

As always, [read the puzzle description](https://adventofcode.com/2020/day/6) before we continue…

We are given answers from groups of people, where

> However, the person sitting next to you seems to be experiencing a language barrier and asks if you can help. For each of the people in their group, you write down the questions for which they answer "yes", one per line. […] (Duplicate answers to the same question don't count extra; each question counts at most once.)

We have more than one group, and

> Each group's answers are separated by a blank line, and within each group, each person's answers are on a single line. For example:

This tells us that we have one of those blank-line separated files again, so I will go for

```python
f = open('/Users/mailund/Projects/adventofcode/2020/06/test.txt')
groups = f.read().split('\n\n')
```

to read the groups, so I do not have to handle the last group as a special case. The part about duplicated answers counting as one tells us that we should think of the answers as sets. In each group, we want each of the unique answers, with no duplicates, and an easy way to get that is to use a set.

Our task is to count how many unique answers we have for each group, and then add these together. A straightforward solution could look like this:

```python
res = 0
for group in groups:
    unique = set()
    for answer in group.split():
        unique.update(answer)
    res += len(unique)
print(f'Puzzle #1: {res}')
```

We can also create a set of all the unique answers in a group by splitting the group—which gives us the strings there—then joining them to get a sequence of all the characters and then remove duplicates by putting that into a set. This gives us a more concise (but a little less readable) solution:

```python
res = sum( len(set(''.join(group.split()))) for group in groups )
print(f'Puzzle #1: {res}')
```

We are flattening each group into one string, and then we use a set to count the unique letters.

With Puzzle #2, we need to count the unique letters that occur in *all*, instead of *any* of the answers in a group. Where Puzzle #1 was set union, we now have set-intersection.

The two puzzles are so alike that we should be able to refactor our code to solve both puzzles. For Puzzle #1, we should do set union on all the answers, and for Puzzle #2, we should do set intersection, and immediately I thought `reduce()` as the functional way to do this. The `reduce()` function will apply a function over a sequence, taking the result of the previous application as the input of the next. So if you have a sequence `x = [a,b,c]` and a function `f()`, then `reduce(f,x)` will give you `f(a,f(b,f(c)))` (or possibly applied in the other direction, depending on the implementation). So, we should be able to apply set union and set intersection and be done with that.

Well, almost. The input sequence to our `reduce()` is a list of strings, the individual answers in the group, and we can’t do union/intersection on strings. So for my first attempt, I used a third argument to `reduce()` that works as an initial value. If you do `reduce(f,x,i)` you get `f(f(a,f(b,f(c,i))))`. The initial value for union should be the empty set, that we continuously add to, and for intersection we should use the full set of letters, that we subtract from. My implementation looked like this:

```python
from functools import reduce
from operator import or_, and_
import string

def solve_puzzle(groups, set_update, set_init):
    return sum(len(ans) for ans in
        (reduce(
           lambda answers, ans: set_update(answers, set(ans)),
           group.split(),
           set_init
         ) for group in groups)
        )

def puzzle1(infile):
    return solve_puzzle(infile, or_, set())
def puzzle2(infile):
    return solve_puzzle(infile, and_, set(string.ascii_lowercase))

print(f'Puzzle #1: {puzzle1(groups)}')
print(f'Puzzle #2: {puzzle2(groups)}')
```

We still have a loop—well, generator expression—over the groups, and in each group, we have a reduce over the split group. In each reduce call, I translate the string part into a set using a lambda-expression. I use `or_` and `and_` for the operators `|` and `&`, that works as union and intersection in Python.

But this is a pretty stupid solution. The reason I need the initial sets and the lambda expression is that I am working on strings and not sets for one of the parameters. I could just as well translate all the strings into sets before I `reduce()`, and simplify the code that way. So I changed it into this:

```python
def solve_puzzle(groups, set_update):
    return sum(map(len, (reduce(set_update, map(set, group.split()))
                         for group in groups)))

def puzzle1(infile):
    return solve_puzzle(infile, or_)
def puzzle2(infile):
    return solve_puzzle(infile, and_)

print(f'Puzzle #1: {puzzle1(groups)}')
print(f'Puzzle #2: {puzzle2(groups)}')
```

The `map(set, group.split())` code translates all the strings into sets, and the sequence of sets is then the input to `reduce()`. This means that we can use the `set_update()` function directly, and we don’t need an initial value—`reduce()` can take that from the sequence.

I like this solution, and if you are used to functional programming, it will be natural to you. However, the flow of data in it can be hard to read. This is not particular to this solution, but the way that mapping and reducing often works. The same as for generator expressions and list comprehensions that we have to read backwards, you have to read expressions that work as arguments to function calls in a nested way.

If you use a pipeline syntax, as they have in R or Elixir, the flow of data is easier to read. You read it from left to right, as a series of transformations. (If you use function composition as in Haskell, it is the same idea, you just read it from right to left). So I wanted to try a version with that as well.

In R, we have had pipes for some years through the `magrittr` package, but if you get the development version of R, you get a new syntax for functions and pipelines. For functions, you can write `\(…) …` for `function(…) …` and you can use `|>` for pipelines. I haven’t used those yet and now is my chance.

I used exactly the same idea. Split the groups by double newlines, then split the answers inside a group by newlines. Here, I had to discard empty strings, because the last group would have one, and I got the annoying special case back. Then, for each group, you split the answers into individual letters, make those into a set, and use `reduce()` to combine them, with a function parameter to handle Puzzle #1 and #2. Map this procedure through all the groups, get the size of the sets, and sum them. My code looks like this:

```r
library(tidyverse)

# Separate functions because string handling is a mess in R
split_groups  <- \(x) str_split(x, "\n\n")[[1]]
split_answers <- \(x) str_split(x, "\n")[[1]] |> discard(\(x) x == "")
make_set      <- \(x) str_split(x, "")[[1]]

fname  <- '/Users/mailund/Projects/adventofcode/2020/06/test.txt'
groups <- read_file(fname) |> split_groups()

solve_puzzle <- function(upd) {
  group_answers <-
	  \(x) x |> split_answers() |> map(make_set) |> reduce(upd)
  solve_puzzle  <-
	  \(x) x |> map(group_answers) |> map_dbl(length) |> sum()
  solve_puzzle
}

puzzle1 <- solve_puzzle(union)
puzzle2 <- solve_puzzle(intersect)

puzzle1(groups)
puzzle2(groups)
```

The string handling at the top is just a nuisance. I always feel that way when working with strings in R. Don’t get me wrong, I love programming in R, but I don’t want to work with strings there if I can at all avoid it.

I could simplify it a bit if I used the old `%>%` pipes because I didn't need to make the `\(x)` functions and could have used `. %>%` instead, but I wanted to try the new syntax.

It is not an entirely fair comparison with the Python code when I split the code into two functions, but even if I hadn’t, reading the pipeline from left to right, instead of inside out, is easier.

Since it is such an easy puzzle this day, I decided to try handling it in C as well. You can use bit-vectors to represent the sets. We only have lower-case English letters, so we can pack the 26 letters into an `int` (which is unlikely to be smaller than 32 bits on any desktop platform), and then all the set manipulation becomes bit manipulation. Bitwise OR and AND on an integer is lightning fast, so it is a good solution. The size of a set is the number of set bits, and if you go outside of the C standard just a tiny big, you can use your compiler’s `__builtin_popcount()` if you have it (or something similar). On an x86-64 you can get the number of set bits with a single instruction, and that is what you get through this operation.

```c
#include <stdio.h>

#define N (26 + 2)
char buf[N];

int handle_group(int *un, int *inter)
{
    *un = 0; *inter = ~0;
    while (fgets(buf, N, stdin)) {
        if (buf[0] == '\n') return *un; // zero if we read nothing
        int ans = 0;
        for (char *x = buf; *x != '\n'; x++) ans |= (1 << (*x - 'a'));
        *un |= ans; *inter &= ans;
    }
}

#define set_size(set) __builtin_popcount(set)
int main(void)
{
    int un, inter, count_un = 0, count_inter = 0;
    while (handle_group(&un, &inter)) {
        count_un += set_size(un);
        count_inter += set_size(inter);
    };
    printf("%d %d\n", count_un, count_inter);
    return 0;
}
```

After playing around long enough, it dawned on me that even the functional solution to the problem wasn’t as Pythonic as I would expect. Surely, we could do even better! Of course, we can; there is always a good solution after you have tried everything else. And for Python, you can use `set.union` and `set.intersection` with a sequence of sets, so we don’t need the `reduce()`. The rest is the same, we still map over the groups and the answers to make them into sets, but those two set functions handle the `reduce()` part:

```python
def puzzle(f):
    return lambda groups: sum(
        len(f(*map(set, group.split())))
        for group in groups
    )
puzzle1 = puzzle(set.union)
puzzle2 = puzzle(set.intersection)
print(f'Puzzle #1: {puzzle1(groups)}')
print(f'Puzzle #2: {puzzle2(groups)}')
```


## Day 07 — Handy Haversacks

The [problem description](https://adventofcode.com/2020/day/7) speaks of bags containing bags, but you should quickly see that we are looking at a graph problem, where the bags are nodes and containment is direct edges.

Parsing the input is the hardest this day, but a little `split()`’ing and a little regular expression quickly get us there. I parsed the bags into a table, where each back holds a list of the bags it can contain, together with how many of each bag it can hold. We don’t need the latter for Puzzle #1, but I suspected, rightly, that it would be needed for Puzzle #2.

```python
import re
bags_table = {}
for line in open('/Users/mailund/Projects/adventofcode/2020/07/input.txt'):
    bag, subbags = line.strip().split(" bags contain ")
    bags_table[bag] = []
    if subbags == "no other bags.": continue
    for sbag in [bag.strip() for bag in subbags.split(',')]:
        no, bagtype = re.match(r"(\d+) (.+) bag.*", sbag).groups()
        bags_table[bag].append((bagtype,int(no)))
```

For Puzzle #1, we need to work out how many bags can hold a shiny golden bag. If we see the puzzle as a graph problem, the question is how many nodes have a path to the shiny golden node. In a general graph problem, we would have to worry about cycles, but here we have a *directed acyclic graph* (DAG), so we can explore recursively from each node, without keeping track of already visited nodes. The base case is the shiny golden bag, which is obviously reachable from itself, and the recursive case checks if any of the neighbours can reach the golden bag:


```python
## Puzzle 1
def explore1(bag):
    if bag == 'shiny gold': return True
    return any(explore1(sbag) for sbag,_ in bags_table[bag])
# subtract one from the sum for the gold bag itself
print(f"Puzzle #1: {sum(explore1(bag) for bag in bags_table) - 1}")
```

We are not supposed to include the golden bag itself when we count, so subtract one from the result.

For Puzzle #2, we have a single-source problem—we explore paths out of the single shiny golden bag. We have to count how many other bags it can hold, and this is once again a simple graph exploration. For each bag, count itself as one, and then add how many bags it can hold recursively. For each immediate neighbour, we know the weight of the edge, it is the number of the given bag we can put into the current one, and we multiply the answer from the recursion with that. Again, we subtract the gold bag itself.

```python
## Puzzle 2
def explore2(bag):
    return 1 + sum(n * explore2(sbag) for sbag,n in bags_table[bag])
print(f"Puzzle #2: {explore2('shiny gold') - 1}") # -1 for the gold bag itself
```

While we don’t need to worry about an infinite recursion because of a cycle in the graph, we do have the possibility of reaching the same node via multiple paths. When this happens, we recompute values, and we waste time on that. An easy solution to that is to remember previous function calls and return a cached value. We can do this explicitly using set, but in the `functools` module, you can find decorators that can handle it for you. One such is `cache`.

```python
from functools import cache
```

There are others, where you have more control over how long the function will remember a call, but `cache` will work for us. There are similar functions in many other languages, but sometimes you have to implement it yourself. It is usually not much of a problem if you have a dictionary/table structure to work with.

In Python, we can use `cache` as a decorator, so we get functions that only compute a value once, and remember it for later, by putting `@cachd` in front of the function definitions:

```python
## Puzzle 1
@cache
def explore1(bag):
    if bag == 'shiny gold': return True
    return any(explore1(sbag) for sbag,_ in bags_table[bag])
print(f"Puzzle #1: {sum(explore1(bag) for bag in bags_table) - 1}") # -1 for the gold bag

## Puzzle 2
@cache
def explore2(bag):
    return 1 + sum(n * explore2(sbag) for sbag,n in bags_table[bag])
print(f"Puzzle #2: {explore2('shiny gold') - 1}") # -1 for the gold bag itself
```

When I tested it, I went from 122 ms down to 45, so it gives us a little bit. Enough that it is worth it if the data was much larger, but hardly anything that matters for data of this size.

It is good to have this trick in the bag when you need to recursively compute something, and it is called *memorisation*. I am not going to explain why, since you can probably guess. It is a crude version of *dynamic programming*, where you usually work out the order you need to compute something before you start, and then make sure that you have what you need when you need it. Dynamic programming solves one of the future problems much faster than careful thinking, but I will get back to that when we get there…


## Day 08 — Handheld Halting

[Day 8](https://adventofcode.com/2020/day/8) was the day I enjoyed the most, so far. We get to implement a simple virtual machine.

There isn’t anything difficult to interpreting the problem description. There are three operations that the machine can do, and we get a program and need to work out what the accumulator is when it enters an infinite loop.

It is a little funny that the problem we should solve is the [halting problem](https://en.wikipedia.org/wiki/Halting_problem), considering that this is undecidable. No problem, however clever, can solve the general case. Of course, we are nowhere near the general case. We have a virtual machine, but it is extremely limited in what it can do. We can jump from operation to operation, but those jumps are independent of the accumulator. This makes the machine a deterministic finite automaton, and finding a cycle in *those* is trivial.

The simples solution to Puzzle #1 is to just run the program. For each instruction, you can immediately see how you should update the accumulator and how you should move the instruction pointer—the position in the program where the next instruction is.

I have implemented finite state machines many times before, and simple virtual machines a handful of times, so I had a good idea about how I wanted to attack the problem. I probably wrote a little too much code for this particular case, where a few if-statements in a loop would do the trick, but I just fell back to habits.

For the machine, I wrote a state class. It holds the instruction pointer and the accumulator. For each instruction, I gave it a method that performed the action. That is the part that would work just as well with if or switch statements. Then, again because of habits, I put the methods in a table to switch on in the program. After that, it is just getting an instruction from the program, use the opcode to get the method in the state object and apply it. We need to stop when we enter an infinite loop, which happens when we see the same instruction a second time, and I use a set for that. It is the last part that makes the “halting problem” easy for finite state machines. It doesn’t matter what the accumulator is when we return to an instruction. The program will repeat the instructions it ran since the last time it was here. That isn’t guaranteed if jumps are conditioned on the accumulator’s value, and in that case, we cannot solve the problem at all. Luckily, we were not asked to solve the general case…

```python
with open('/Users/mailund/Projects/adventofcode/2020/08/input.txt') as f:
    prog = [tuple(cast(x) for cast,x in zip((str,int), inst.split()))
            for inst in f.readlines()]

class State(object):
    def __init__(self):
        self.instp = 0 # instruction pointer
        self.acc_ = 0  # accumulator
    def nop(self, operand):
        self.instp += 1
    def acc(self, operand):
        self.acc_ += operand
        self.instp += 1
    def jmp(self, operand):
        self.instp += operand

def run_prog(prog):
    visited = set()
    state = State()
    ops = {op: getattr(state,op) for op in dir(State) if not op.startswith('__')}
    while state.instp < len(prog):
        if state.instp in visited: return state.acc_
        visited.add(state.instp)
        op, operand = prog[state.instp]
        ops[op](operand)

print(f"Puzzle #1: {run_prog(prog)}")
```

For Puzzle #2, we get to modify the program to fix the infinite loop. We are allowed to change one `nop` into a `jmp`, or one `jmp` into a `nop`. Successful completion of the program is defined as one that takes us to the instruction address one past the program length.

The easiest solution is probably to just try modifying the program. If you can iterate through all the changes you are allowed, you can run each modified program, and if you get a successful run, you have your program. If that happens, you should return the accumulator value, but you already have that from the run.

We can modify the program from above, so it detects both loops and successful termination:

```python
def run_prog(prog):
    visited = set()
    state = State()
    ops = {op: getattr(state,op) for op in dir(State) if not op.startswith('__')}
    while state.instp < len(prog):
        if state.instp in visited: return ('Abort', state.acc_)
        visited.add(state.instp)
        op, operand = prog[state.instp]
        ops[op](operand)
    return ('Success', state.acc_)
```

Then we can modify the program in a generator, and keep modifying until we get a success:

```python
def alternative_progs(prog):
    for i, (op, operand) in enumerate(prog):
        if op == 'nop':
            prog[i] = ('jmp', operand)
            yield prog
            prog[i] = ('nop', operand)
        if op == 'jmp':
            prog[i] = ('nop', operand)
            yield prog
            prog[i] = ('jmp', operand)

for alt_prog in alternative_progs(prog):
    res, acc = run_prog(alt_prog)
    if res == 'Success':
        print(f"Puzzle #2: {acc}")
        break
```

It is reasonably fast, so there is no need to come up with a better solution. However, I have never really liked brute force when I know that there must be something smarter. So I also tried to look at the program as a graph problem. (You don’t gain anything from it, speed-wise, it turns out, but we are doing this for fun, so who cares?)

Think about your program as a graph. Each instruction is a node, and they all have edges to the next instruction. That is the next in the program for `nop` and `acc`, and it is the address you jump to for `jmp`. If we allow modifications, then jump and nop nodes now have nodes they can go to, where one of them is the modified program. You need to find a path from the first instruction to one past the last, that goes through exactly one modification edge.

This problem is not that different from the recursive graph problems for the previous day, but this time we can return to a node we have already seen. That is, after all, how we determine that we have an infinite loop. If you want to traverse a graph in such a case, you should keep track of visited nodes. Often, you will have a graph representation where you can put a tag in a node, but otherwise, a set or a dictionary will get the job done. We can use a set as we did above.

We will write a function, `def locate_index(prog, seen, i, j)`, that explores node `i` in program `prog`, where `seen` contains the nodes we have already explored, and where `j` is the instruction we have modified, if any. The traversal will be recursive as before, but with two base cases. If we reach the end of the program, we will return `j`—we are looking for the instruction to modify, and we can return it when we have a successful modification. If we return to a previously visited instruction, we also return, but we return to the caller that will explore other options. For the recursive cases, we explore the next node. For an `acc` opcode, that is always `i+1`, but for the other two opcodes, there are two next nodes. We are only allowed one change to the program, so one of the options is only open of `j` is not already set.

The recursion is relatively straightforward, but I implemented a hack to handle successful program termination. If we reach the end of the program, we want to return `j`, but we want to return it all the way to the initial call of the function. If not, we would have to test, everywhere in the recursive function, if we already had the result that we are searching for, and then return that instead of traversing further.

In some languages, you have “call/cc”, or *call with current continuation*. Even in C, where it is called `longjmp()` and is an insanely powerful `goto`. It is a way of returning from a function, all the way up the stack to some previously set program state. You don’t return through all the function calls along the way, but go directly where you need to go.

We also have it in Python, but it is hidden very well. We have such “non-local” returns when we use exceptions. They are not usually exploited to simplify (and speed up) recursive functions, but it works just fine. We will use an exception to return from the recursive function. If we get to the end of the program, we raise the exception, and where we call the function the first time, we are ready to catch it. This way, we circumvent the functions waiting on the stack.

My implementation looks like this:


```python
# hack for non-local return
class CallCC(Exception):
    def __init__(self, resval):
        self.resval = resval

def callcc(f, *args):
    try:
        f(*args)
    except CallCC as x:
         return x.resval

def locate_index(prog, seen, i, j):
    if i == len(prog): raise CallCC(j)
    if i in seen: return

    seen.add(i)
    op, operand = prog[i]
    if op == 'acc':
        locate_index(prog, seen, i+1, j)
    elif op == 'nop':
        locate_index(prog, seen, i + 1, j)
        # switch to jmp
        if j is None:
            locate_index(prog, seen, i + operand, i)
    else: # op is jmp
        locate_index(prog, seen, i + operand, j)
        # switch to nop
        if j is None:
            locate_index(prog, seen, i + 1, i)
    seen.remove(i)

def change_index(prog):
    idx = callcc(locate_index, prog, set(), 0, None)
    op, operand = prog[idx]
    if op == 'nop': prog[idx] = 'jmp', operand
    else:           prog[idx] = 'nop', operand

change_index(prog)
print(f"Puzzle #2: {run_prog(prog)}")
```

It doesn’t speed up anything, to be honest. It doesn’t find the instruction to modify much faster than if I run all the modified programs. For larger programs, I suspect it would. But we are not in a world where we get larger programs for this machine (I suspect), so if I wasn’t actively trying to avoid real work, this would have been a waste of time.

I wanted to play some more with the virtual machine, so I also implemented it in C. Compared with the Python solution to Puzzle #1, there isn’t anything new. I use a byte-vector instead of a set since C doesn’t have builtin sets and I didn’t feel like writing one. It is a global variable, and those are initialised as all zeros, so it was an easy choice.


```c
#include <stdio.h>
#include <string.h>

struct command { int inc_instp; int inc_acc; };
struct state   { int instp;     int acc;     };
#define CMD(ii, ia) \
  (struct command){ .inc_instp = (ii), .inc_acc = (ia) }

#define N 1000 // the program is shorter than this...
struct command PROG[N];
char visited[N];

static int parse_asm(void)
{
    int n = 0; char buf[4]; int operand;
    while (scanf("%s %d\n", buf, &operand) == 2) {
        if (strcmp(buf, "nop") == 0)      PROG[n++] = CMD(1, 0);
        else if (strcmp(buf, "acc") == 0) PROG[n++] = CMD(1, operand);
        else /* jmp */                    PROG[n++] = CMD(operand, 0);
    }
    return n;
}

struct res { enum { SUCCESS, FAILURE } status; int res; };
#define SUCC(state) (struct res){ .status = SUCCESS, .res = state.acc }
#define FAIL(state) (struct res){ .status = FAILURE, .res = state.acc }

#define UPD(s, cmd) /* important to upd acc before instp */ \
  do { s.acc += cmd.inc_acc; s.instp += cmd.inc_instp; } while(0)

static struct res run(int n)
{
    struct state state = { .instp = 0, .acc = 0 };
    while (state.instp != n) {
        if (visited[state.instp]) return FAIL(state);
        visited[state.instp] = 1;
        UPD(state, PROG[state.instp]);
    }
    return SUCC(state);
}

int main(void)
{
    struct res res = run(parse_asm());
    switch (res.status) {
        case SUCCESS: printf("SUCCESS: %d\n", res.res); break;
        case FAILURE: printf("FAILURE: %d\n", res.res); break;
    }
    return 0;
}
```

I didn’t use a class and dispatch on opcodes, because I can’t do that in C. There are no classes. I could have made a table of function pointers, but by now, I had realised that all three operations could be considered pairs of numbers. What do they add to the accumulator and what do they add to the instruction pointer. This doesn’t quite work for Puzzle #2, because you cannot differentiate between, for example, `acc 0` and `nop 42`, since both add zero to the accumulator and add one to the instruction pointer, and only one of them can be modified. But I don’t care about Puzzle #2 that much; it was the first puzzle and the virtual machine I wanted to play with. So I just represent the program as pairs of numbers, and I update the state by adding one number to the instruction pointer and one to the accumulator.


Because I have been playing a little with *just in time* (JIT) compilation for my upcoming book, I thought it could also be fun trying something like that. The idea would be to translate the program we have in our input into machine code, and run the program directly on the hardware. I quickly dismissed it, because I would still have to keep track of the previously seen instructions, and most of the code would be updating a bit-vector, and nothing was interesting in that.

However! We don’t actually have to keep track of which instructions we have seen, as long as we stop executing as soon as we see an instruction again. So we can write *self-modifying code*. This is a no-no and not something you should ever do. On many OSes, you can’t. They will not allow you to have memory that you can both write to and execute at the same time. Well, macOS allows me to, and I will exploit it.

The idea is this: every instruction will start with code that turns itself into a return. Then, if we ever come back to an instruction, the function will automatically return. Easy. Well, the idea is. There is some work to be done.

If you haven’t generated code before, there are a few things you should know. First, your memory has access permission, and memory you get from `malloc()` is read/write, but to execute it, you need to add an execution bit. How you do that differs between operating systems, but on UNIX machines, you can use `mprotect()`. That only works if your memory is page-aligned, however, and to allocate page-aligned memory, you should use `mmap()`. I am lazy here, so I allocate memory that already has the execution bit set, but you are not necessarily allowed to. Sometimes, you must first write the code you generate, with write permissions, and then switch to read/execute afterwards. This won’t work with self-modifying code, though.

I used this code to allocate a buffer for machine code. The program is around a thousand instructions long, but I will use 16 bytes per instruction (for reasons I explain below), so I allocated four pages. The page size on my machine is 4096. I put a counter at the bottom of the allocated memory so I can keep track of how much code I have emitted.

```c
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <sys/mman.h>

// There is about 1k instructions and I need 16 bytes per
// instruction, so I allocate four pages for the jit'ed code
#define PAGESIZE 4096
struct jit_buf {
    unsigned char buf[4 * PAGESIZE - sizeof(int)];
    int next_inst;
};
struct jit_buf *alloc_jit_buf(void)
{
    int protection = PROT_WRITE | PROT_EXEC;
    int flags = MAP_ANONYMOUS | MAP_PRIVATE;
    struct jit_buf *buf = mmap(0, 4 * PAGESIZE, protection, flags, -1, 0);
    if (!buf) return 0;
    buf->next_inst = 0;
    return buf;
}
```

Then I wrote some generic doe for emitting bytes and integers, and for emitting “padding” code. It is the instruction NOP, opcode 0x90, but it is a NOP in x86-64 assembler and not in our input code. That also relates to those 16 bytes that I get back to.

```c
// General code emission functions
static inline
void emit_byte(struct jit_buf *buf, char byte)
{ buf->buf[buf->next_inst++] = byte; }

static inline
void emit_int(struct jit_buf *buf, uint32_t n)
{ emit_byte(buf, n & 0xff); emit_byte(buf, (n >> 8) & 0xff);
  emit_byte(buf, (n >> 16) & 0xff); emit_byte(buf, (n >> 24) & 0xff); 
}

// This is just to make addressing easier. We can use the same
// number of bytes for each instruction, and that way have a simple
// jmp instruction. Instructions start at multiples of 16
static inline
void pad(struct jit_buf *buf, int bytes)
{ for (int i = 0; i < bytes; i++) emit_byte(buf, 0x90); /* nop */ }
```

With the System V ABI, the return value of a function is in register `rax`, so I will keep the accumulator there. That way, when the generated code returns, I have my accumulator value. The first instruction I emit will set this register to zero. It is the instruction `xor rax, rax` and that is the machine code `0x48, 0x31, 0xc0`.

```c
// For setting up the JIT function -- we need to start with acc = 0
static void zero_acc(struct jit_buf *buf)
{   // xor rax, rax
    emit_byte(buf, 0x48); emit_byte(buf, 0x31); emit_byte(buf, 0xc0);
}
```

The return instruction, `ret` is opcode `0xc3`, and we have a function for emitting that as well:

```c
// If we reach the end of the program, use this to return
static void ret(struct jit_buf *buf)
{
    emit_byte(buf, 0xc3); 
}
```

Now for translating the input instructions, and why I use 16 bytes for each. The addresses we jump to with the input `jmp` instructions are relative to the position in the input program, and each instruction has length one there. But in the code we generate, instructions do not have the same size. So index `i` in our input must be translated into some address `a` in the generated code. With a bit of bookkeeping and analysing the program, we could calculate the correct positions, but I am lazy, so I decided to give all the instructions the same size in the emitted code. That way, I can compute the target address when I need it, without analysing the program.

How many bytes do I need, then? Each instruction will start with the code the modifies the program. It looks like

```asm
	mov byte[rip - 7], byte 0xc3
```

It is not valid `nasm` assembler because of the `rip` (register instruction pointer) there, but it is close. It tells the machine to put 0xc3 into the address that is 7 before the instruction pointer. The opcodes for the instruction are `0xc6, 0x05`, then -7 as twos-complement, little-endian, and finally `cxc3`. It is seven bytes in total (first two instruction bytes, then a four byte integer, and then the `ret` instruction, which is one byte). The -7 is because we write relative to the address after we have read the instruction, so it refers to the position of the first opcode.

After this guard code, the `acc` instruction must add to the `rax` register

```asm
acc:
	mov byte[rip - 7], byte 0xc3 ; 7 bytes
	add rax, dword <n>           ; 6 bytes
```

where `<n>` is a 4-byte integer.

For `jmp` we must do

```asm
jmp:
	mov byte[rip - 7], byte 0xc3 ; 7 bytes
	jmp <n>                      ; 5 bytes
```

Our `nop` shouldn’t do anything, except the guard

```asm
nop:
	mov byte[rip - 7], byte 0xc3 ; 7 bytes
```

So the base code is 7 byte for `nop`, 12 for `jmp`, and 13 for `acc`. Computers really like powers of 2, so I rounded the largest up to 16. It isn’t strictly necessary here, I think, but I was hacking it together rather quickly. It means that I need to put some padding after all the instructions, but so be it.

The functions below emit the three types of instructions we have in our virtual machine:


```c
// Here we write some self-modifying code that
// will return from the function if we ever return
// to this point. The instruction is
// mov byte[rip - 7], byte 0xc3
// where 0xc3 is the opcode for ret.
static void return_guard(struct jit_buf *buf)
{
    emit_byte(buf, 0xc6); emit_byte(buf, 0x05); // mov a byte
            emit_int(buf, -7);                  // write to 7 bytes back
            emit_byte(buf, 0xc3);               // the `ret` opcode
}

static void nop(struct jit_buf *buf)
{
    return_guard(buf);
    pad(buf, 9);
}

static void acc(struct jit_buf *buf, int n)
{
    return_guard(buf);
    // add rax, dword <n>
    emit_byte(buf, 0x48); emit_byte(buf, 0x05); emit_int(buf, n);
    pad(buf, 3);
}

static void jmp(struct jit_buf *buf, int n)
{
    return_guard(buf);
    // jmp <n> -- adjust for the address of this instruction
    //               and then 16-step jumps for steps in our VM instructions
    emit_byte(buf, 0xe9);
    if (n > 0) emit_int(buf, 16 * (n - 1) + 4);
    else       emit_int(buf, 16 * n - 12);
    pad(buf, 4);
}
```

The `jmp` instruction is a little complicated, even with the rule about instructions having length 16, since the actual `jmp` opcode doesn’t sit at the beginning of a virtual machine instruction. It sits after the guard code and is relative to the opcode there. But it is just a question of adjusting for the position, and it means that you have to compute the address differently when you jump forwards and backwards. Because the instruction doesn’t sit in the middle of the virtual machine instruction either, so it is not the same distance that you need to jump.

From here on, the code looks like the first C version. Read in the input string, emit the corresponding code, and then execute it:

```c
static int (*parse_asm(void))(void)
{
    struct jit_buf *buf = alloc_jit_buf();
    zero_acc(buf); // setup accumulator in generated function
    char opcode[4]; int operand;
    while (scanf("%s %d\n", opcode, &operand) == 2) {
        if (strcmp(opcode, "nop") == 0)      /* emit => */ nop(buf);
        else if (strcmp(opcode, "acc") == 0) /* emit => */ acc(buf, operand);
        else /* jmp */                       /* emit => */ jmp(buf, operand);
    }
    ret(buf); // add a return if we reach the end of the program
    return (int (*)(void))buf;
}


int main(void)
{
    int (*prog)(void) = parse_asm();
    printf("%d\n", prog());
    return 0;
}
```

There was nothing algorithmic to it, but it was a lot of fun nevertheless.
