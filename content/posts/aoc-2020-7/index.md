+++
title = "Advent of Code 2020 — day 19"
date = 2020-12-19T06:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

I will make this one quick, because I don’t have much time. [Today, we are given some rules](https://adventofcode.com/2020/day/19) for what strings should look like, and we are to validate a set of strings and count how many are valid. This is a bit of a mix between the parser from yesterday and the rule-validation from other days, but leaning, by far, towards the parser. The rules are a grammar, and checking the strings means we are matching them against the grammar.

Yes, there are more or less standard ways to do this, but you try to be quick, and then you mess it up. Then you have to do it all again…

Anyway, in Puzzle #1 there are no cycles, so all derivations are finite, and if you wanted to, you could generate all strings and test them. You could also use the rules to generate regular expressions—it is essentially what they are, with they form they have—and then use a regular expression library to solve the puzzle.

With Puzzle #2, you do get cycles. If you have cycles, you might have a problem, when it comes to grammar rules. A straightforward recursive function that attempts to match a string against the rules can get into an infinite loop. 

If you have to parse an expression, and one of the rules has itself as the first sub-rule, blindly trying each possible match will not work. If, for example, you have a rule that says that an expression can be:

```
expression := number | expression BINOP expression | '(' expression ')'
```

then recursing on it can take you from expression to expression to expression … and you never end.

You can usually rewrite the grammar go avoid it, and that would be my preferred choice. Other options are hard.

This wasn’t the issue in the input we got, at least for my input (we all get different input). With the grammar we have, we can always make progress along the string for each rule we apply, so although an `expression` might contain an `expression`, it doesn’t *start* with an `expression`. There is no problem with a rule like

```
expression := number | '(' expression ')'
```

because you have always read another character before you get back to the `expression` rule.

When this is the case, you can parse and backtrack when you cannot apply the next rule you are trying. The backtracking is necessary if you blindly apply rules, because somewhere, deep in a match of a rule, you might not be able to continue further, but then there might be another rule that will get you to the goal.

My first solution did this search with backtrack, but I made a mistake in it—otherwise I would have solved both puzzles at the same time. I would apply the rules in order, and pick the first that matches. This is a greedy approach, and it worked for my first data. However, with the changed rules, it failed, because you might be able to match a rule, but then later in the string, other rules can’t match. So I had to change the implementation to keep searching until I had a match to the end. In the code below, I do this search using generators; my solution to Puzzle #1 returned matches instead, or threw exceptions if they couldn’t match.

If only I had done it correct the first time… that seems to be the mantra for the parsing exercises for me.

Anyway, my solution is brute-force matching rules. When there are more than one possible rule to apply, I try all of them. To get this to work, all the rule checking is done with generators.

```python
class CharRule(object):
    def __init__(self, char):
        self.char = char
    def check(self, x, i):
        if i < len(x) and x[i] == self.char:
            yield i + 1

class SeqRule(object):
    def __init__(self, seq):
        self.seq = seq
    def check(self, x, i, r = 0):
        if r == len(self.seq):
            yield i
        else:
            for j in RULES[self.seq[r]].check(x, i):
                yield from self.check(x, j, r + 1)

class OrRule(object):
    def __init__(self, seq_rules):
        self.seq_rules = seq_rules
    def check(self, x, i):
        for rule in self.seq_rules:
            yield from rule.check(x, i)

import re
def parse_rules(rules):
    RULES = {}
    for rule in rules.split('\n'):
        m = re.match(r'(\d+): "(.)', rule)
        if m:
            i, char = m.groups()
            RULES[i] = CharRule(char)
        else:
            i, seqs = rule.split(':')
            seq_rules = []
            for seq in seqs.split('|'):
                seq_rules.append(SeqRule(seq.split()))
            RULES[i] = OrRule(seq_rules)
    return RULES

def matches(test, RULES):
    for i in RULES['0'].check(test, 0):
        if i == len(test): return True
    return False

f = open('/Users/mailund/Projects/adventofcode/2020/19/input.txt')
rules, tests = f.read().split('\n\n')
RULES = parse_rules(rules)
tests = tests.split('\n')
print(f"Puzzle #1: {sum( matches(test, RULES) for test in tests )}")

RULES['8']  = OrRule([SeqRule(['42']),SeqRule(['42','8'])])
RULES['11'] = OrRule([SeqRule(['42', '31']),SeqRule(['42','11', '31'])])
print(f"Puzzle #2: {sum( matches(test, RULES) for test in tests )}")
```

There is probably some regularity to the rules, because the puzzle hinted at it, but this solution should work as long as you do not have any cycles of rules that do not make progress by reading at least one character.

You could clean it up a bit, but I have to stop now, or I will get in trouble…
