+++
title = "Advent of Code 2020 — days 01-05"
date = 2020-12-14T04:48:38+01:00
draft = false
tags = ["Python", "programming"]
categories = ["Programming"]
+++

While I wait for comments on the last chapters of my upcoming C-pointers book, I have some time on my hands. And since corona keeps me at home, I have to find something to keep me entertained. So I thought I would write a little about the [Advent of Code](https://adventofcode.com) puzzles I’m solving this year, and how I am solving them.

This is the first year that I am trying Advent of Code, and I am having a lot of fun with it, and the occasional frustration of course, but that is not the primary reason I want to tell you about it. In my Computational Thinking class, I tell my students that much of programming and problem solving is basically pattern matching. Not in the programming language / Haskell-like pattern-matching sense, but in the sense that we recognise a problem as something we have seen and solved before, and exploit this to handle the related problem. And this is essentially what something like Advent of Code is all about.

If you go to the [homepage](https://adventofcode.com), you can see the kind of puzzles you get every day (and I will be linking to them instead of repeating them here), and you get a feeling for what kind of problems you need to solve. They are phrased in humorous ways, as is typical for many competitive programming puzzles, but aside from that, it is a description of a problem in a form you can run into in real life. In the wild, you rarely run into a problem phrased as “do a depth-first traversal of a tree” or “find the all-pairs shortest path”. Those are exercises you get in programming and algorithmic classes. Still, a large part of problem-solving is recognising that a description of something else boils down to an algorithmic problem such as these. And that is something that we are bad at teaching in said classes.

Even if we didn’t write exercises that explicitly told you which algorithm we wanted you to implement, we would be giving the solution away from context. If I just gave a lecture on queues and stacks and then handed you a sheet of exercises, you would be safe to assume that you probably could use either stacks or queues to solve those exercises. This can lull you into a false sense of security. I read a study some years ago that showed that maths teachers in many cases couldn’t solve the kind of problems they gave their students if they didn’t have the context that the students had. If you know that something is a trigonometry problem, you are 90% there to solving it. If you don’t, the same problem is massively harder to handle. To really practise problem-solving, you need to work on problems without the context; but, of course, to have a fair chance of solving them, you need the background knowledge you could map the problems into.

You cannot easily do this in a teaching context. You would need one class where you give the students all the programming and algorithmic (and in many cases the mathematical) background, and then another where you just throw problems at them. The second part won’t get through the student program evaluation, as it is too diffuse. But all is not lost. There are plenty of online competitive programming servers that you can guide the students to. This year, I told my Computational Thinking class to try out [Kattis](https://open.kattis.com). I haven’t spent much time there myself, to be honest, but I have played a little, and I felt confident that they could solve the easier problem with the introduction to programming that they have had. They don’t have enough computer science background for the harder problems, but the “mapping a description to a problem I know” part is just as good for a 1.5 point puzzle as for a 5.1 point one.

I didn’t know about the Advent of Code until a few weeks ago, or I would also have suggested that they try that. Maybe not, though, now that I have tried it myself. The puzzles get harder, and for some of the cases, if you don’t know the underlying trick you need, the problems are *very* hard. Even if you are incredibly clever, you will need to know some tricks. There are probably many ways to solve the same problems, but I have managed to get to today’s puzzle only by recognising an underlying computational problem that I could implement. I don’t think I would have made it if I had to invent it all myself. When I go through the puzzles, I will tell you the tricks I am using, and what they are called so you can read up on them if you don’t know them already. If problem-solving is pattern matching to a large degree, then knowing more patterns means you are a better problem solver. We all reach for some standard tools in our toolbox when we need to solve a problem, and my solutions are based on the toolbox that I have and will differ from others. But the larger the toolbox you can assemble, the better you will get.

A word of warning is in order, though. While puzzles such as these are more realistic than exercises in class are, the setting is still artificial in many ways. The problems and the solutions are realistic enough, that is not an issue. But because you are in a programming competition, you already know that there is a solution, and you know that the solution will be quick. If your program has to run for hours to solve the problem, you know that you have the wrong solution. That is definitely not the case in real life.

Some problems are impossible to solve. The [Halting Problem](https://en.wikipedia.org/wiki/Halting_problem) shows up as a puzzle this year, but in a very restricted form that you can solve. Sometimes, people will ask you to solve undecidable problems (I heard about a case just last week), and there you need a different toolbox. Not one that tells you how to solve it, but one that lets you recognise that it cannot be done. Just as bad are intractable problems. Sure, they *can* be solved, but not in the time you have available, so you need to recognise that as well. In both cases, you can at best approximate a solution, and that is what you must do. With competitive programming challenges, you can safely assume that the problems are not of this kind.

You are also safe to assume that the input data you get is correct, which let me tell you is rare in real life. You don’t worry about faulty input, you don’t have to write parsers that give meaningful errors when the data is corrupted or anything like that. Those are skills you probably need someday, but not what we practise in these kinds of challenges. And I won’t spend much time on parsing data in my solutions either. If I get the input into my program in the correct form, I am done. I only have that input, so I don’t worry about what I might have gotten. Well, on Kattis you have to worry about the input you haven’t gotten because they test your program on their own data, but they won’t throw malformed input at you at least.

The context you have with something like Advent of Code is that you are looking to map a description to a problem that has a relatively fast solution, and once you have a fast answer you are done. Well, fast enough, and you are done. You don’t need to go for optimal running time or anything like that. You have one data set to run your program on, and if it is fast enough for you, then it is fast enough. (On Kattis there are runtime constraints, so there you might have to be a little more careful). So, mostly, you know that there is a puzzle—they are even called that—and it has a clever solution that you are looking for. This is not how the real world works, there you do not know that there is a clever solution hiding in plain sight, but it is the best-case scenario, and solving these puzzles is an excellent exercise for real-world problem solving nonetheless.

The difficulty increases day by day, so the first few puzzles and solutions might feel anticlimactic. They did to me. But it gets better. I don’t know if I will make it all the way through. Day 13 gave me a scare—not because I couldn’t solve it, but because I solved it by being lucky enough to remember a result from a math class I took more than 20 years ago. More of that, and I might fail. But I will add solutions here as I have time to write them up, likely, the last few days will be some time after Christmas, as I have the strong sense from the wife that while I *might* be allowed to solve the puzzles, I am not allowed to sit and blog over the holidays. So if I write something there, it is while she is sleeping).

Anyway, that is a lot of writ with no code, so let us get started. I feel like there will be plenty of commentaries as we go along—[Note: there was].

## Day 01 — Report Repair

In [Day 1](https://adventofcode.com/2020/day/1), there is a straightforward “puzzle”, and I put it in quotes because there isn’t much of a puzzle to it. Read it yourself, and you will quickly see that the task is spelt out very clearly. Puzzle #1 asks you to find two numbers that add to 2020 and then multiply them. I promise that it gets more interesting later.

It is always a good idea to try the simplest you can think of first, to see if that can get you there. Sometimes, the simplest solution will be too slow, and if it is obviously an exponential running time approach, you might want to think a little harder, but that isn’t the case here. You can just run through all pairs of input, add them to test if they sum to 2020, and if they do, you return their product. Easy.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/01/input.txt')
x = list(map(int, f.read().split()))

def brute_force(x):
    for i in range(len(x)):
        for j in range(i):
            if x[i] + x[j] == 2020:
                return x[i] * x[j]
print(f"Puzzle #1: {brute_force(x)}")
```

I solve most of the problems in Python, as it is my go-to language for most problems. For high-speed solutions, I use C, and for data analysis, I use R, but for problems such as this, Python is always my first choice. Not because it is a better language, but just because I am familiar with it and have used it for many years.

The input is in a text file, and I need it as integers. The easiest way to get that is to read everything into memory, split the resulting string, so you get each integer as a separate item in a list, and then translate those strings into integers. The `f.read().split()` does the reading and splitting, and `map(int, …)` applies the function `int()` to every item in the list, giving us a new list as result. Since `int()` will turn the strings into integers, we get what we want. Since Python 3, `map()` gives us an iterator object rather than a list, but we want to index into `x`, so we turn it into a list with the call to `list()`. This isn’t the most readable code for I/O, but it isn’t unusually terse either. For quick and dirty code, I write something like this. If I had to be more careful with input data, for example, to validate it or such, I would be more careful. I will not be more careful for any of the puzzles in Advent of Code.

The two nested for-loops are self-explanatory, I think. It is a quadratic time algorithm, but on the data we get, it runs in milliseconds.

For Puzzle #2, you have to do the same with triplets, and it is just as simple:

```python
def brute_force(x):
    for i in range(len(x)):
        for j in range(i):
            for k in range(j):
                if x[i] + x[j] + x[k] == 2020:
                    return x[i] * x[j] * x[k]
print(f"Puzzle #2: {brute_force(x)}")
```

Now the running time is cubic, but I can still manage both puzzles in 200 milliseconds on my five-years-old iMac, so it isn’t a problem.

Sometimes, brute force is fast enough, and then you go with that. There is nothing wrong with that. In today’s problem, Day 14, I spent almost an hour and a half trying to see a trick to go from exponential running time to something better and failing. When I gave up and implemented the brute force solution, I could analyse the data in 172 milliseconds. And I feel a little stupid about that because I always tell my students (and readers in general) to go for the simple solution first, and then check if it is fast enough before you try to be clever. You have to consider the tradeoff between programmer time and running time. If it takes you two minutes to implement a slow algorithm, but one that is fast enough for your purposes, don’t waste any time on making it faster with a smarter algorithm, that may take you an hour or day to implement. It isn’t worth it.

My students will do bioinformatics later in life, at least most of them, and a lot of that is data science where you need to massage some data and then throw it at a pipeline. If you expect to massage this particular data a couple of times, it doesn’t matter much if it takes an hour to do. Make the computer run overnight. Your own time is more important than the computer’s, and you can do something useful while it churns the data. If, on the other hand, and this is what they sometimes forget is part of the message, you need to handle a lot of data, or you give your program to a lot of people who have to run it, then you do want to make it fast. I’m pretty sure that we could cut our computing cluster in half if people spent a little more time on implementing better algorithms. But it always is a tradeoff, and you need to consider it.

With Advent of Code, you immediately see how fast the brute force solution is, and if it is fast enough, there really is no point in speeding it up. You need one answer, and once you have it, you are only optimising the code for fun. Not because you need it. (Of course, it is fun, so you should still do it if you have some ideas for making it faster).

Still, because the brute force solution is exponential on Day 14, I didn’t follow my own advice, and I suffered from it. The day 1 puzzles are clearly simple enough that brute force is the way to go.

You can speed the first puzzle up with a rather simple trick, though. If you use a set, you can check if it contains a number you want in constant time. Python’s sets are hash tables, and they give you that performance. If you put `2020 - y` for all `y` in the input into a set, you can check if there is a number you can use there, and then get the product:

```python
def hash_trick(x):
    s = { 2020 - y for y in x }
    for y in x:
        if y in s:
            return y * (2020 - y)
print(f"Puzzle #1: {hash_trick(x)}")
```


It is a linear time solution because you spend linear time building the set and linear time searching for the number you want, so better than the quadratic time we had. In walltime, however, I see a reduction from 50 milliseconds to 45, so hardly something I would spend any more time on.

## Day 02 — Password Philosophy

Go to the [puzzle page](https://adventofcode.com/2020/day/2) and read the description before we continue…

So, the puzzles involve checking passwords. The input is on the form 

```
1-3 a: abcde
1-3 b: cdefg
2-9 c: ccccccccc
```

where we first have a range of integers, then a letter, and then a password, and we need to count how many passwords are valid, according to some rules. For Puzzle #1, the rule is that the number of occurrences of the letter is in the range. 

If you want to count the number of occurrences of various items in a sequence, such as a list or string, you want to use `Counter` in the `collections` module. In the puzzle, we only need to count the number of occurrences of one letter, and `Counter` will give us a table of all of them, so we might be able to write something faster ourselves, but it won’t be faster by much, and we will have wasted a lot of time on it. So just use `Counter`.

If we use `Counter`, we can run through each line in the input, parse the line, and count. My solution looks like this:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/02/input.txt')
data = f.readlines()

from collections import Counter

count = 0
for line in data:
    intv, let, x = line.split()
    let = let[0]
    a,b = map(int, intv.split('-'))
    if a <= Counter(x)[let] <= b:
        count += 1
print(f"Puzzle #1: {count}")
```

The first three lines in the loop parse the line. First, I split on whitespace. The first line in the input above is `1-3 a: abcde`, so the result of splitting is `[“1-3”, “a:”, “abcde”]`. Then I extract the letter as the first character in the middle token (so I get rid of the colon), and I split the range on `-` to get the two integers, that I convert into integers using the `map(int, …)` construction. It might have been easier to use a regular expression here, but those are never my first choice. I use them when I feel that it makes things easier, but I don’t find them that easy to read or write, so more often than not, I write code like this instead. This is a case, however, where a regular expression might have been easier…

Once we have parsed the data, we use `Counter()` to get a table of how many times each character appear in the password. We can look up the count for letter `let` using sub-scripting, and we check if it is in the valid range. I love that Python let’s us chain comparisons like `a <= x <= b`, but of course it isn’t much harder to split it into `a <= x and x <= b` if you use a language that doesn’t.

Puzzle #2 changes the task, so instead of checking if the occurrence of `let` is in a range, we need to check that `let` occurs at one, and only one, of the indices `a` or `b`.

Parsing the data is the same, but the task clearly uses 1-indexing while Python uses 0-indexing, so we need to adjust `a` and `b`. To check if `let` occurs exactly once on index `a` or `b` we could count how many times it occurs, we could explicitly check that `let` is at index `a` and not `b` or vice versa, or any other number of things. I used XOR, the `^` operator in Python:

```python
count = 0
for line in data:
    intv, let, x = line.split()
    let = let[0]
    a,b = map(int, intv.split('-'))
    a, b = a - 1, b - 1
    if (x[a] == let) ^ (x[b] == let):
        count += 1
print(f"Puzzle #2: {count}")
```

If you write a lot of code in R, the `^` operator is dangerous for you. It exponentiates in R and does XOR in Python. Use `**` both places if you want to avoid confusing the two.

Now, XOR is a bit-wise operator, so you also want to be careful when you use it. It works as logical xor when you use it on `bool`, but a lot of non-boolean objects can be interpreted as “falsy” and “truthy”, including integers. If you use `^` on integers, you get xor, but not the xor that you want. There are many ways to get logical xor, but the easiest is to cast your objects to `bool`: `bool(a) ^ bool(b)`. We don’t need to here, of course, because the result of the `==` comparison is boolean already, so it all works out.

I also find this solution equally readable:

```python
count = 0
for line in data:
    intv, let, x = line.split()
    let = let[0]
    a,b = map(int, intv.split('-'))
    a, b = a - 1, b - 1
    if (x[a] == let) + (x[b] == let) == 1:
        count += 1
print(f"Puzzle #2: {count}")
```

It makes it explicit that we are counting the number of matches and requiring that it is exactly one. But it is mostly a matter of taste, I guess.

## Day 03 — Toboggan Trajectory

Read the [problem description](https://adventofcode.com/2020/day/3) before you continue…

We are still in the stage of Advent of Code where the problem descriptions very explicitly tell you what to do, and here the description tells you to move through a map, in steps that are integral numbers in the x and y coordinate, in Puzzle #1, you go 3 right and 1 down in each step. And you have to count how many trees you will encounter when you do this. The description about how the map continues repeating itself is the kind of obfuscation you often see in puzzles, but if a map repeats itself like this, it means that you should be workmen with indices modulo the size of the map. Since the map only repeats itself in the horizontal direction, we don’t have to do this as we go down, but any index you have for a horizontal coordinate, you take the index modulo the width when you need to check the map. I saw solutions on Twitter where people expanded the map by copying rows to some sufficiently large number, but it isn’t necessary. Your old friend, the `%`-operator, will do it for you.

To read the map, I got all the lines in the input using `readlines()` and then got rid of the newline characters with `strip()`. It is not the only way, but I think that it is the easiest. If we read the data this way, then we directly have the map as a list of strings, and we can index into these to get the trees. If `tree_map` is our list, then `tree_map[i]` is row `i`, the row distance `i` from the top, and `tree_map[i][j]` is the symbol at index `j` in that row.

Then, to do the wrapping with modulo, we need the width of the map, which is the length of the lines. You can get that from the length of any of them as they are the same. We also need to know how deep the map goes in the vertical direction, so we can stop when we have reached the end, and that is just the length of the map.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/03/input.txt')
tree_map = [line.strip() for line in f.readlines()]
n, m = len(tree_map), len(tree_map[0])
```

To count the trees you can just iteratively apply the steps, adding to coordinates `i` and `j`, until you reach the bottom of the map. In each iteration, you check if you hit a tree, and if you do, you increment a count:

```python
def count_trees(right, down):
    i, j = 0, 0
    count = 0
    while i < n:
        if tree_map[i][j] == '#':
            count += 1
        i += down
        j = (j + right) % m
    return count
```

The function is parameterised with the step sizes since we need those in Puzzle #2. When you do the puzzles, you don’t know what comes later, but I was lucky enough to write the function this way in the first go. Usually, I am not and have to go back and refactor.

For Puzzle #1, we count the trees on a path that goes three right and one down, so this is our solution:

```python
print(f"Puzzle #1: {count_trees(3,1)}")
```

For Puzzle #2, you get several paths and have to compute the product of the result. We can make a list of paths and apply `count_trees()` to each path like this:

```python
paths = [(1,1), (3,1), (5,1), (7,1), (1,2)]
counts = [count_trees(*p) for p in paths]
```

The `count_trees(*p)` calls the function with the arguments in path `p`. The function takes two arguments and not a single tuple-argument, which is what we have in `p`, so the `*` makes the function consider the tuple as arguments.

We need the product over all paths. We have the function `sum()` that would be useful if we had to add them, but we don’t have a builtin `prod()` function that does the same for multiplication. There is one in the `math` module, however, so get that one, and you are done:

```python
import math
print(f"Puzzle #2: {math.prod(counts)}")
```


## Day 04 — Passport Processing

[Day four](https://adventofcode.com/2020/day/4) is the first where I think the problem description doesn’t directly give you the solution as well. Read the description, and then we look at a solution.

So, we are tasked with validating passports, and for Puzzle #1, we need to check if a passport has at least seven mandatory fields and optionally an eight. I couldn’t read from the description how passports might be invalid in ways other than having missing fields, so I read it to mean that we needed to check if we had these exact fields. Still, looking at the data later I suspect you could cheat a little… anyway, I will solve the problem as if we had to check for either having seven or eight fields and that these fields should be exactly those we allow.

```python
def valid_passport(fields):
    return fields == {'byr', 'iyr', 'eyr', 'hgt', 'hcl', 'ecl', 'pid'} \
        or fields == {'byr', 'iyr', 'eyr', 'hgt', 'hcl', 'ecl', 'pid', 'cid'}
```

This isn’t an optimal solution, of course. We compare sets, and we compare the same fields against two sets with overlapping fields, so we could optimise it. But I think the function is very clear in what it is doing, and it will be fast enough, so I am happy with it as it is.

That means that to solve Puzzle #1, we merely need to collect all passports and throw this validation function at them. The input comes in lines with one or more fields, with a blank line between passports. The fields have a key, a colon, and then the key’s value:

```
ecl:gry pid:860033327 eyr:2020 hcl:#fffffd
byr:1937 iyr:2017 cid:147 hgt:183cm

iyr:2013 ecl:amb cid:350 eyr:2023 pid:028048884
hcl:#cfa07d byr:1929

hcl:#ae17e1 iyr:2013
eyr:2024
ecl:brn pid:760753108 byr:1931
hgt:179cm

hcl:#cfa07d eyr:2025 pid:166559648
iyr:2011 ecl:brn hgt:59in
```

A straightforward solution could look like this:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/04/input.txt')
passport_fields = set()
no_valid = 0
for line in (line.strip() for line in f):
    if not line:
        if valid_passport(passport_fields):
            no_valid += 1
        passport_fields = set()
        continue

    for key, val in (x.split(':') for x in line.split()):
        passport_fields.add(key)
if valid_passport(passport_fields):
    no_valid += 1

print(f"Puzzle #1: {no_valid}")
```

We process each line in turn, and we use a set of fields, `passport_fields`, where we collect the fields from the current passport. If we see a blank line, we are done with the passport we are currently handling, so we validate it, and reset the `passport_fields` set to empty. Otherwise, we split the fields in the line using `split()` (it splits on whitespace), and then we split in `:` to separate the key from the value. We only need the key in this puzzle, so we put it in our set.

I don’t like this approach much, because I always forget to handle the last item in a line-separated file. If we had terminal blank lines, we wouldn’t have a special case here, but we have separators instead, and I don’t like those. I cannot always avoid them, but if my input is small enough—and with tiny data from toy examples like this it is—I can split the passports in a simpler way, that better matches my way of coding.

If I do this:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/04/input.txt')
passports = f.read().split('\n\n')
```

I get a list of the passports. I split on blank lines, and that will give me all the individual passports, without a special case at the end. If I want the fields in a passport, I can split on whitespace:

```python
for passport in passports:
    fields = passport.split()
```

and with a little bit of generator comprehension, I can get myself the set of fields

```python
for passport in passports:
    fields = { key for key,val in (field.split(':') for field in passport.split()) }
```

Here, I split the passport string to get the fields, split each field in key and value, and build a set of the keys. The puzzle tells us to count how many of them are valid, and if we interpret the result of `valid_passport()` as integers, zero or one, we can use `sum()` to get it:

```python
f = open('/Users/mailund/Projects/adventofcode/2020/04/input.txt')
passports = f.read().split('\n\n')
no_valid = sum(
  valid_passport({ field.split(':')[0] for field in passport.split() })
  for passport in passports
)
print(f"Puzzle #1: {no_valid}")
```

I like these kinds of expressions because they let me write concise code, and in my opinion, succinct (as long as not directly obfuscating) code is easier to read and maintain. The only thing that I do not like about them is that you have to read them backwards. Sometimes, that feels natural to me. A `sum(f(x) for x in y)` reads like mathematical notation, and I don’t have any problem with following the logic. But when you process several loops in one expression, as we do above, something like R’s (new) pipelines, or tidyverse’s existing ones would make the code much clearer.

I didn’t feel up to implementing my own notation for pipelines, and even if I did, it wouldn’t be easier for others to read, since they would need to learn a new domain-specific language to do so, so I didn’t take it further. I played a little with using generators, but that didn’t make it more elegant either. Splitting the code into functions to make it clearer that way didn’t do anything for me either. You just split the same functionality over multiple lines, which means that there is more that you need to read and understand to follow the code. So this is as good as I could make it, and it isn’t that bad, I think.

For Puzzle #2, we have to validate each field following different rules. This is a simple exercise in reading and implementing rules. I wrote a function per field, with a little bit of reuse for checking ranges, and put them into a map, from where I could get the function that matches a field.

```python
def year_validator(year, x, y):
    year = int(year)
    return x <= year <= y

def height_validator(height):
    if height.endswith("in"):
        height = int(height[:-2])
        return 59 <= height <= 76
    elif height.endswith("cm"):
        height = int(height[:-2])
        return 150 <= height <= 193
    else:
        return False

valid_hair_chars = { *'abcdef0123456789' }
def hair_colour_validator(hair):
    if hair[0] != '#': return False
    hair = hair[1:]
    if len(hair) != 6: return False
    for x in hair:
        if x not in valid_hair_chars:
            return False
    return True

valid_eye_colour = {'amb', 'blu', 'brn', 'gry', 'grn', 'hzl', 'oth'}
def eye_colour_validator(eyes):
    return eyes in valid_eye_colour

def pid_validator(pid):
    if len(pid) != 9: return 0
    try:
        int(pid)
        return True
    except:
        return False

validators = {
    'byr': lambda year: year_validator(year, 1920, 2002),
    'iyr': lambda year: year_validator(year, 2010, 2020),
    'eyr': lambda year: year_validator(year, 2020, 2030),
    'hgt': height_validator,
    'hcl': hair_colour_validator,
    'ecl': eye_colour_validator,
    'pid': pid_validator,
    'cid': lambda x: True
}
```

Given a passport, you now run through its fields, if there is a field not in the table the passport is invalid, and otherwise you use the corresponding function to validate it.

```python
valid1 = {'byr', 'iyr', 'eyr', 'hgt', 'hcl', 'ecl', 'pid', 'cid'}
valid2 = {'byr', 'iyr', 'eyr', 'hgt', 'hcl', 'ecl', 'pid'}
def valid_passport(fields):
    keys = set(fields)
    if keys != valid1 and keys != valid2: return False
    for key, val in fields.items():
        if not validators[key](val):
            return False
    return True
```

When parsing the input, we need to build a dictionary for the fields instead of a set. We can do this by simply putting the expression in a call to `dict()` and using the full result of `field.split(‘:’)` instead of just the first value.

```python
f = open('/Users/mailund/Projects/adventofcode/2020/04/input.txt')
passports = f.read().split('\n\n')
no_valid = sum(
    valid_passport(dict(field.split(':') for field in passport.split()))
    for passport in passports
)
print(f"Puzzle #2: {no_valid}")
```


## Day 05 — Binary Boarding

Read the [puzzle description](https://adventofcode.com/2020/day/5), and pay attention to the title of the day, *binary* boarding. 

In this puzzle, we have to figure out what to do ourselves again, and to add insult to injury, the description is likely to mislead you into solving the problem using binary search. You can use a binary search, but it is far from the easiest or fastest solution, so I consider the seat decoding description as pure misdirection.

The description sounds like a binary search. If you see ‘F’ you are in this interval, and if you see ‘B’ you are in that, and then if you are in this interval ‘F’ sends you here, and ‘B’ sends you there, etc. Don’t let this fool you. The ‘F’ and ‘B’ encoding tells you where you go if you were doing a binary search. However, if you performed a binary search and wrote down the directions you took as bits, you would have written down the index you ended up at in binary (well, plus/minus one depending on how you index). So what the encoding really is, is a binary number. You just have to decode this particular encoding. The ‘F’ and ‘B’ characters are bits, ‘F’ is zero and ‘B’ is one.

There is another bit of misdirection. The description tells you to decode row and column separately, but a column is a three-bit number, and you are to multiply the row by 8 and then add the two. Well, multiplying by 8 is the same as shifting the number by three bits, so *really* both row and column encode a single binary number. For the row part, ‘F’ is zero and ‘B’ is one, and for the column ‘L’ is zero, and ‘R’ is one. That is all there is to Puzzle #1: taking the sequence and interpret it as a binary number. Getting the largest number once you have decoded them is trivial.

I have a mental deficiency: when I think low-level code, I think C, so I implemented the solution there first:

```c
#include <stdio.h>

#define N 10
char buf[N];

static int encode(char *start, char *end)
{
  int val = 0;
  for (; start != end; start++) {
    val <<= 1;
    if (*start == 'B' || *start == 'R') val |= 1;
  }
  return val;
}

int main(void)
{
  int max = 0;
  while (scanf("%s\n", buf) == 1) {
    int pass = encode(buf, buf + 10);
    if (pass > max) max = pass;
  }
  printf("%d\n", max);
  return 0;
}
```

Well, it is faster than Python, but that is in computing time. Not programmer time. The Python solution is much simpler:

```python
trans_table = str.maketrans({'F': '0', 'B': '1', 'L': '0', 'R': '1'})
def decode(x):
    return int(x.translate(trans_table), base = 2)

f = open('/Users/mailund/Projects/adventofcode/2020/05/input.txt')
x = [decode(x.strip()) for x in f]
print(f"Puzzle #1: {max(x)}")
```

I use the string `translate()` method. It needs a translation table that we build with `str.maketrans()`, and then it maps the relevant characters there. It is faster than if we replaced the characters call by calls to `x.replace()`, because it only makes one new string and not one per replacement. Anyway, replace the different FBLR characters to bits, and tell Python that you want an integer encoded in binary using `int(x, base = 2)`, and there you are.

For Puzzle #2, we need to find a missing seat. If you decode the description, you see that between the smallest and the largest passport, there is one empty seat. I didn’t read it that way, and only got that there would be some seat with the one before and the one after occupied, so my C solution looks like this:

```c
#include <stdio.h>

#define N 10
char buf[N];

#define NO_SEATS (1 << N)
int seats[NO_SEATS]; // zero initialised

static int encode(char *start, char *end)
{
  int val = 0;
  for (; start != end; start++) {
    val <<= 1;
    if (*start == 'B' || *start == 'R') val |= 1;
  }
  return val;
}

int main(void)
{
  while (scanf("%s\n", buf) == 1) {
    seats[encode(buf, buf + 10)] = 1;
  }
  for (int i = 1; i < NO_SEATS - 1; i++) {
    if (seats[i - 1] == 1 && seats[i] == 0 && seats[i + 1] == 1) {
      printf("%d\n", i);
      return 0;
    }
  }
  return 0;
}
```

It is plenty fast enough, but one you discover that you are looking for one such index you can also do:

```python
occ_seats = set(x)
all_seats = { *range(min(x),max(x)+1) }
print(f"Puzzle #2: {(all_seats - occ_seats)}")
```

Here, `occ_seats` contains all the occupied seats and `all_seats` contains all seats between the smallest and the largest, and their difference is the one available seat. The `*` in the definition of `all_seats` is rather important, so don’t forget it. We create a set from the elements in the iterator we get out of the call to `range()`, not a set that contains the iterator.

There is a way here that you can get a binary search into the puzzle if you are really dying to do so. If you are searching for the one missing seat in `x`, you can first sort `x`. For all indices less than the missing value, `min(x)+i == x[i]`, and for all indices above the missing value, `min(x)+i == x[i]+1`. You can use that for a binary search. If you started out with a sorted `x`, this would be an excellent idea. However, you don’t. If you have to sort `x` first, you will be using at least O(n) time to do so, and that is only if you do some indexing sort; otherwise, you use O(n log n). The linear scan through the seats in the C code also takes time O(n) and is faster than any sorting attempts. The set-based search is easier to program, and takes fewer lines of code, but is less efficient than the linear scan. It is still faster than the binary search solution, however.

So, yeah, the description tries to trick you into thinking binary search, but you should be thinking binary numbers. Once you see that the seat encoding is a binary number, you are done with the puzzle. I am lucky enough that I have seen such problems often enough that I didn’t have to work it out this time, but of course, I had to the first couple of times I had a problem like this.

