+++
title = "Advent of Code 2020 — days 14-16"
date = 2020-12-17T11:01:39+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

My posts are almost catching up to [Advent of Code](https://adventofcode.com/2020), which probably means that I will fall behind in the weekend. Quit likely, actually. I probably have time for solving the puzzles, but not writing about them. If that happens—and if I were a better man, it is how I would bet—then I will make sure to catch up Monday.

Anyway, today I will get through days 14 to 16. There were all straightforward puzzles, and when I tried to be clever, I would only punish myself. In all cases, I spent more time thinking about smarter ways to solve the problem, than the computer spent on the brute force solution. 

## Day 14 — Docking Data

In [the problem description](https://adventofcode.com/2020/day/14) there is a explanation for a bit-masking procedure. We have some integers and we have a bit-mask, and we should modify the integers according to the mask. If the mask says that there should be a zero, we must modify the number to put a zero there, and if it says that we should have a one, we should put a one there. The masks are 36 bits, so if you work in a language with 32-bit integers, you want a larger integer type. I solved the puzzles in Python, so I don’t worry about integer sizes at all.

I wrote a class to handle masks. It would be easy enough to represent them as raw data, but I want to translate the masks from our input into two integers, where I can perform bit-masking directly. I will have one for setting zeros and another for setting ones.

The zero mask, confusingly enough, mostly holds ones. It is a mask with ones everywhere, *except* the positions that should be zero. If I take an integer and AND it with this mask, then the positions where it holds a zero become zero; all the other bits remain the same.

The one mask does the opposite of the zero mask, it is there to put ones into the input. It starts out as all zeros, but then we put 1-bits at the locations we want to translate into ones. If we OR with this mask, we set the bits at those locations.

This is all standard bit-fiddling stuff, and the class looks like this:

```python
class Mask(object):
    def __init__(self, mask):
        self.zero_mask, self.one_mask = ~0, 0
        for i,b in mask:
            if b == '1': self.one_mask |= (1 << i)
            else:        self.zero_mask &= ~(1 << i)
    def __call__(self, val):
        return (val & self.zero_mask) | self.one_mask
```

I’m not entirely sure why the method for applying the mask is `__call__()`. I think I started out with a function and then turned it into a class, and then I didn’t want to change the code where it was called. It was something like that, but it is lost from my memory.

If you are familiar with bit manipulation, then there should be nothing surprising in that code. If you are not, then it won’t help much if I explain it further; you have to go and read up on that.

Puzzle #1 asks us to go through a program and insert values into addresses in a fictional computer. Before we put a number in memory, however, we need to apply the mask. The computer has a 36-bit memory space, so you don’t want to use an array for this. That is about 69 giga-addresses, and if the integers are 36 bits as well, you need at least five bytes for each address. It is about 350 gigabytes of memory. That won’t fly, so I used a dictionary. The addresses are keys, and the bit-masked integers are the values.

Solving the puzzle is now a simple matter of running through the instructions in the input, extract a mask when the instruction is such a fellow, or apply the mask and insert a value at an address when we see such an instruction. To solve the puzzle, we should add all the values tougher, and we can get those from the dictionary using `.values()`:

```python
import re
f = open('/Users/mailund/Projects/adventofcode/2020/14/input.txt')
program = f.readlines()

def run_prog_1(program):
    mask = Mask(())
    mem = {}
    for inst in program:
        if inst.startswith('mask'):
            parsed_mask = [(i,b) for i,b in enumerate(reversed(inst.split()[-1])) if b != 'X']
            mask = Mask(parsed_mask)
        else:
            addr, val = map(int, re.match(r"mem\[(\d*)\] = (\d*)", inst).groups())
            mem[addr] = mask(val)
    return mem

print(f"Puzzle #1: {sum(run_prog_1(program).values())}")
```

When I work with masked integers, and I have to go through bits, I go in reversed order. Consider binary integers 100 and 10. If I call the first bit for bit one, then bit one is different in the two numbers. It is either the second or third least-significant bit. If you always start at the lowest value, you always know what bit i is supposed to mean. In this puzzle, we have 36-bit numbers, and we could think about our values as such. But if you want the binary representation of an integer in Python, you typically translate it into a string. There, binary 101 and 10 become ‘101’ and ’10’. If you run through them from the right, you get consistent bit-indices. If you do it from the left, you don’t. Then you have to pad the representation. That is not hard to do, but it is easier to run through the bits in reverse order, and I do it several places in the code for this day.

Puzzle #2 threw me in a wrong direction, I freely admit. It isn’t hard to work out what the task is. Instead of masking the values, you must mask the addresses, but each masked address is really multiple addresses, and you must insert the value at all those addresses.

I always tell my students to try the simple approach first; this time I didn’t follow my own advice. I didn’t try to brute force the problem. The test input in Puzzle #1 has a mask with a huge number of X-bits (34 is huge in this context), which would map each address to \\(2^{34}\\) real addresses. That is more than 17 billion addresses. Clearly, brute force is never going to work.

So I spent more than an hour trying to figure out another solution… I didn’t find one. So, I grudgingly decided to have a closer look at the input file. Sometimes, they give us data with more structure than they reveal in the problem descriptions. They never told us we were working with primes in day 13, but that was important for solving the second puzzle there.

The input data doesn’t look like the example mask in Puzzle #1 at all! There, the masks have very few X-bits! The mask with the highest number of X’es had 8. That is \\(2^8 = 256\\). I iterate through that on a regular bases when I radix sort. This does not scare me at all.

So, after wasting a lot of time trying to be clever, I set out to brute force the puzzle.

For every input mask, we have a set of concrete masks to apply to addresses. Each X in the input can either enforce a zero or a one. To get all the combinations, all \\(2^b\\) when there are \\(b\\) X-bits, we can compute the power-set of the indices for the X-bits, and then create zero- and one-masks as above from them:


```python
# damned it, I will brute force this shit...
def powerset(x):
    res = []
    for i in range(2**len(x)):
        s = [] # the set
        for j, b in enumerate(reversed(bin(i))):
            if b == '1': s.append(x[j])
        # the complement
        c = [j for j in x if j not in s]
        # and the masks...
        ones, zeros = 0, ~0
        for j in s: ones |= (1 << j)
        for j in c: zeros &= ~(1 << j)
        res.append((ones,zeros))
    return res
```

An easy way to compute the power-set of a collection of elements is to look at binary numbers from zero to \\(2^b-1\\). The bits in those numbers tell you which elements to include and which to exclude. The function does that for the indices of the X-bits, and then it builds pairs of masks based on them.

So, I updated my `Mask` class, to create the new kind of masks and give me a generator for addresses when applied:

```python
class Mask(object):
    def __init__(self, mask):
        self.one_mask = 0
        self.floating = []
        for i,b in enumerate(reversed(mask)):
            if b == '1': self.one_mask |= (1 << i)
            if b == 'X': self.floating.append(i)
        self.masks = [
            (self.one_mask | one_mask, zero_mask)
            for one_mask, zero_mask in powerset(self.floating)
        ]
       
    def __call__(self, addr):
        for one_mask, zero_mask in self.masks:
            yield (addr | one_mask) & zero_mask
```

After that, solving the puzzle is trivial:

```python
def run_prog_2(program):
    mask = Mask(())
    mem = {}
    for inst in program:
        if inst.startswith('mask'):
            mask = Mask(inst.split()[-1])
        else:
            addr, val = map(int, re.match(r"mem\[(\d*)\] = (\d*)", inst).groups())
            for masked_addr in mask(addr):
                mem[masked_addr] = val
    return mem

print(f"Puzzle #2: {sum(run_prog_2(program).values())}")
```

On Twitter, I saw a lot of people solving the masking puzzle by considering addresses as strings. Still generating the different addresses from a mask, but as string manipulations. That works excellently, when we use a dictionary for our addressing space, and I hadn’t considered that. If you go for computational speed, though, bit-manipulation is better than string manipulation. When you use bit-wise OR, AND, XOR, or such operations, the hardware handles the bits in parallel, and you get very quick operations.

Running time, as long as you are done in a handful of seconds, is not an issue with these puzzles, though. If you can implement the solution in 10 minutes and run it in 10 seconds, you are much better off than if you implement it in 15 minutes and it runs in 5. For me, though, I think that I can implement bit-manipulation code faster than string-manipulation code. I am simply more used to it. But your milage may vary.


It still bothers me that I had to solve the puzzle with brute force, so I went back and looked at it once more. The string-solutions gave me an idea. What if we could represent multiple addresses with a single dictionary key? Maybe, we could apply the masks but keep the X’es. They don’t map to any real address anyway, so they are as good for keys as zeros and ones? An address with \\(b\\) X’es just represent \\(2^b\\) real addresses, and for the solution, we should multiply the corresponding value with that.

This won’t work in general—I honestly have no idea about what I would do in the completely general case—but maybe, just maybe, there is some regularity in the data that would let me do this? They are sneaky with the puzzles, after all.

I didn’t dig into the data as the first step. I learn from my mistakes. I just implemented the idea and checked if it would give me the right answer. If it doesn’t, then the idea doesn’t work. If it does, then I can try to work out under which conditions it work.

Well, I tried…

```python
def run_prog_2_(program):
    mem = {}
    for inst in program:
        if inst.startswith('mask'):
            mask = inst.split()[-1]
        else:
            addr, val = map(int, re.match(r"mem\[(\d*)\] = (\d*)", inst).groups())
            addr = bin(addr).zfill(36)
            masked_addr = ''.join(m if m in 'X1' else b for m,b in zip(mask, addr))
            mem[masked_addr] = val * 2**masked_addr.count('X')
    return mem

print(f"Puzzle #2: {sum(run_prog_2_(program).values())}")
```

It doesn’t work. If I take small prefixes of the data it does, so it is something that could be used for a little while, but it breaks when I am a bit more than halfway through my input.

If I had a way to identify that a new address will clash with my existing data, I might be able to work something out. But I didn’t have time to play with it any longer, so it will be another time…


## Day 15 — Rambunctious Recitation

In [day 15](https://adventofcode.com/2020/day/15) we get an initial sequence and a rule for how to extend it. We have to work out what number 2020 is (and when you get to Puzzle #2, what number 30-million is).

Ha! They are trying to fool me into being unnecessarily clever again. Not this time. I can be lazy with the best of them and just brute force the solution. That took about 10 minutes to implement and 10 seconds to run for both puzzles.


```python
def solve(input, n):
    spoken = { n:(i+1) for i, n in enumerate(input[:-1]) }
    last = input[-1] # misnomer, since it is the current...
    for i in range(len(input), n):
        # we insert 'last' *after* we check if we
        # had spoken it before. That is the only
        # tricky part to this solution...
        curr = 0 if last not in spoken else i - spoken[last]
        spoken[last] = i ; i += 1 ; last = curr
    return last

input = [2,0,6,12,1,3]
print(f"Puzzle #1: {solve(input, 2020)}")
print(f"Puzzle #1: {solve(input, 30_000_000)}")
```

The rule for working out the next number tells you to look back to the previous time you saw it. That is misdirection. You don’t want to search back in a growing sequence, when all you need to know is the last time you saw a number. For something like this, you always reach out for a table instead of a sequence.

The only tricky part with implementing the rule is that you need to insert the current number in the table, and determine what the next should be, based on the last time you saw the current number. That means that you must wait with inserting the current number until you have computed the next. Otherwise, it is pretty simple.

This was quick, and I was much surprised when I saw that the simple solution to Puzzle #1 solve Puzzle #2 as well. It takes about nine seconds on my machine, and I was tempted to implement it in C to speed it up. But, although I do have some [hash tables lying around](https://amzn.to/37scTNu), I didn’t feel like spending an hour adapting one to this problem, just to go from ten to one second running time. Maybe one day when I am bored. But not today.

I still feel a bit disappointed that I had to simulate the process to get the n’th number. So I asked a domesticated number theorist. It isn’t quite the [Van Eck Sequence](https://www.numberphile.com/videos/van-eck-sequence), but it is pretty close, so he wasn’t optimistic. Then I am not going to be either.


## Day 16 — Ticket Translation

In [day 16](https://adventofcode.com/2020/day/16) we have to infer which fields on a ticket corresponds to which set of numbers. Our input consist of rules that the different kinds of fields must obey, our own ticket, and a set of other tickets that we can use to map the order of field-values to the field rules.

Each rule is a list of ranges, with the interpretation that a field is valid for that rule if it is in one of the ranges. When I parse up the data, I put ranges and rules in classes, to make it easier to keep track of them, and easier to test if a given value obeys a given rule. Tickets, both my own and the nearby tickets, are lists of numbers.

```python
# -- Parsing the input ---------------------------------------
f = open('/Users/mailund/Projects/adventofcode/2020/16/input.txt')
rules_description, ticket, nearby = f.read().strip().split('\n\n')

# Parsing rules...
class Range(object):
    def __init__(self, a, b):
        self.a = a
        self.b = b
    def check(self, val):
        return self.a <= val <= self.b
    def __repr__(self):
        return f"Range({self.a}, {self.b})"

class Rule(object):
    def __init__(self, name, ranges):
        self.name = name
        self.ranges = ranges
    def check(self, val):
        return any(r.check(val) for r in self.ranges)
    def __repr__(self):
        return f"Rule({self.name},{self.ranges})"

rules = []
for line in rules_description.split('\n'):
    rule, ranges = line.split(':')
    rules.append(
        Rule(rule.strip(), [
             Range(*map(int, x.strip().split('-')))
                   for x in ranges.split('or')
    ]))

# Parsing my ticket
def parse_ticket(ticket):
    return list(map(int, ticket.split(',')))
my_ticket = parse_ticket(ticket.split('\n')[1])

# Parsing nearby tickets
nearby_tickets = []
for ticket in nearby.split('\n')[1:]:
    nearby_tickets.append(parse_ticket(ticket))

```

For Puzzle #1, we need to add together all the fields that cannot satisfy any rule. With an object `r` from the `Rule` class, I can check if a field satisfy the rule with `r.check(field)`, so solving the puzzle is easy. Go through all the tickets and all the fields, identify those that do not satisfy any rule, and sum those:

```python
# Puzzle #1
def ticket_scanning_error(tickets, rules):
    return sum(sum(field for field in ticket
                   if not any(r.check(field) for r in rules))
               for ticket in tickets)

print(f"Puzzle #1: {ticket_scanning_error(nearby_tickets, rules)}")
```

The loop is a little backwards, because that is how these generator expressions work, but it is just the double loop over tickets and fields.

In Puzzle #2, we now need to work out which rule matches which field. We can do this by elimination. A rule that doesn’t satisfy all the values in a field, cannot match that field.

Before we can identify which rules match which fields, we must clean up the ticket data, by removing all tickets with a field that isn’t satisfied by any rule. That is an expression similar to the one we wrote above. We go through all the tickets and check if all fields can be satisfied:

```python
# Get the valid tickets to work with...
def check_ticket(ticket):
    return all(
        any(r.check(field) for r in rules)
        for field in ticket
    )
valid_tickets = [ *filter(check_ticket, nearby_tickets) ]
```


We can work out which rules can potentially match a field by applying a variant of [day 6](https://mailund.dk/posts/aoc-2020-2/). In the puzzles there, we had a set of answers and we worked out the union and intersection of those across groups. Here, we have a set of rules, that are satisfied by each value, and across the fields we identify the rules that satisfy all of them using an intersection. We can do something like this (see the context below):

```python
def candidate_rules(field):
    return { r.name for r in rules if r.check(field) }
def satisfying_rules(fields):
    return set.intersection( *map(candidate_rules, fields) )
field_rules = [ *map(satisfying_rules, fields) ]
```

If `fields` are the values in the tickets, collected so we have all the values that come first, then those that come second, and so forth, then we map `satisfying_rules` over them. (In the code below, we wrap this in an `enumerate()` so we get the order as well, but that is not essential here). The `satisfying_rules()` function works out which rules satisfy all the values in a field, and it does that by computing the intersection of `candidate_rules()`, that extracts the rules that a given value can satisfy. The result of it all is a list of sets, where for each index `i` in the list, you have the set of rules that can match to that field.

If these are all singletons, then we are done. Then we have mapped one rule to each field. If they are not, we need to do some kind of pairing. Optimal pairing isn’t necessarily trivial, but for the data I had, this strategy worked. I took all the fields with a singleton, and then removed the rules in them from the remaining rules. If a field only satisfy a single rule, then it must be assigned to that rule. This leaves new singletons, and I do the same again. The fields that now have singletons are assigned to those rules, and I remove the rules from the remaining. Iterate this until you have a single rule for all the fields, and you are done.


```python
# Get the rules that each field can satisfy...
def infer_rules(tickets):
    # I want the fields, rather than the tickets, so transform...
    fields = [[ticket[j] for ticket in valid_tickets]
              for j in range(len(valid_tickets[0]))]

    # For each field, identify the candidate rules
    def candidate_rules(field):
        return { r.name for r in rules if r.check(field) }
    def satisfying_rules(fields):
        return set.intersection( *map(candidate_rules, fields) )
    field_rules = [ *enumerate(map(satisfying_rules, fields)) ]

    # Now start eliminating...
    assigned_rules = []
    while field_rules:
        singletons =  [ (i,r) for i,r in field_rules if len(r) == 1 ]
        field_rules = [ (i,r) for i,r in field_rules if len(r) > 1  ]
        assigned_rules.extend(singletons)        
        removed = set.union( *[r for i,r in singletons] )
        for _,s in field_rules:
            s -= removed

    assigned_rules.sort()
    return [ name for _,(name,) in assigned_rules ]
```

The elimination code here will not always work. It assumes that we will always have singletons, so it will break if we for example end up with two fields left that can both satisfy the same two rules. If we are in such a situation, either assignment would be correct, but we would not have a unique solution. For these puzzles, I’m reasonably sure that there are unique solutions, so I dared assume it.

To finish the puzzle, we extract the names that begin with “departure”, get the corresponding values, and multiply them:

```python
rule_names = infer_rules(valid_tickets)
indices = [ i for i,r in enumerate(rule_names)
              if r.startswith("departure") ]

from math import prod
print(f"Puzzle #2: {prod(my_ticket[i] for i in indices)}")

```

