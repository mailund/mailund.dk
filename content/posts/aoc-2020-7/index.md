+++
title = "Advent of Code 2020 — day 19"
date = 2020-12-19T06:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

I will make this one quick, because I don’t have much time. [Today, we are given some rules](https://adventofcode.com/2020/day/19) for what strings should look like, and we are to validate a set of strings and count how many are valid. This is a bit of a mix between the parser from yesterday and the rule-validation from other days, but leaning, by far, towards the parser. The rules are a grammar, and checking the strings means we are matching them against the grammar.

Yes, there are more or less standard ways to do this, but you try to be quick, and then you mess it up.

In Puzzle #1, there are no cycles in the grammar rules, and I implemented a quick recursive solution, that matches each sub-rule as far as I can, and then continue from that point with the next rule. I used an exception to quickly abort when I didn’t get a match, sort of similar to the Call/CC thing I had some days ago. It was simple, and it was quick, but it broke *completely* in Puzzle #2, where there are now cycles.

If there are cycles in a grammar, the easiest way to get a fast parser is often to rewrite the grammar, so it is deterministic. There isn’t any problem with cycles, that is not where the trouble enters the issue, but there is with non-determinism. If you have to parse an expression, and there are more than one rule you can apply, then simple recursion might mean that you recurse on the same part of the string indefinitely. If you have a rule that says that an expression can be:

```
expression := number | expression BINOP expression | '(' expression ')'
```

then recursing on it can take you from expression to expression to expression … and you never end.

You can rewrite the grammar go avoid it.

That wasn’t the issue in the input we got, and my solution (below) cannot handle it. With the grammar we have, we can always make progress along the string for each rule we apply, so although an expression might contain an expression, it doesn’t *start* with an expression. There is no problem with a rule like

```
expression := number | '(' expression ')'
```

because you have always read another character before you get back to the `expression` rule.

When this is the case, you can parse and backtrack when you cannot apply the next rule you are trying.

My code for Puzzle #1 was *almost* there, but the way I used exceptions to abort a match couldn’t handle multiple searches. With backtracking, when you give up on one rule, you go back through the parse tree and find a rule that has more options, and for all of those, you keep going until you find something that matchs. My Puzzle #1 implementation was greedy, and it did go back and retry, but it would *always* insist on matching as much as possible. In many ways, it was similar to regular expressions, and not the more general rules we have in Puzzle #2.

So I had to throw everything out, and implement a new version. I didn’t try to be smart with this, because I really have to finish quickly if I want to program in a weekend, so I made every grammar rule a generator, that could give me all possible matches. Matching would then consist of applying nested rules until I have a match that captures the entire input string.

The code for Puzzle #2 can handle both puzzles, and I only list it below:

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
print(f"Puzzle #2: {sum( matches(test, RULES) for test in tests )}")

f = open('/Users/mailund/Projects/adventofcode/2020/19/input2.txt')
rules, tests = f.read().split('\n\n')
RULES = parse_rules(rules)
tests = tests.split('\n')
print(f"Puzzle #2: {sum( matches(test, RULES) for test in tests )}")

```

You could probably clean it up a bit, but I have to stop now, or I will get in trouble…
