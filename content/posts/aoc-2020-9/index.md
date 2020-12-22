+++
title = "Advent of Code 2020 — day 22"
date = 2020-12-22T06:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++


This will be the last post I write before New Year. We have vacation in the house from tomorrow, and I won’t be hacking when I am supposed to be social—I am told. I will do the last three puzzles, and post them, after the holiday.

But it was a nice and easy day today, with one small irritant that took up most of the time I spent on the puzzles. Anyway, to it!

[The task today is to play a game of cards.](https://adventofcode.com/2020/day/22). For Puzzle #1, the description of the game is straightforward, and so is the implementation.

For once, parsing the data is easy:


```python
f = open('/Users/mailund/Projects/adventofcode/2020/22/test.txt')
def parse_player(player):
    return tuple(map(int, player.strip().split('\n')[1:]))
player1, player2 = map(parse_player, f.read().split('\n\n'))
```

I place player hands in a `tuple()`, and that becomes important later!

The way the game is played is well described, and the simplest imaginable implementation will solve the puzzle:


```python
def play(p1, p2):
    while p1 and p2:
        if p1[0] > p2[0]:
            p1 += (p1[0],p2[0])
        else:
            p2 += (p2[0],p1[0])
        p1, p2 = p1[1:], p2[1:]
    return p1 if p1 else p2

result = sum((i+1)*x for i,x in enumerate(reversed(winner)))
print(f"Puzzle #1: {result}")
```

I didn’t use a `tuple()` but a list in my first implementation. That will still work, because the algorithm doesn’t have to leave the function arguments unchanged, and the code works equally well with lists or tuples. But the `+=` operator will modify its left-hand side. In Puzzle #2, I changed the representation to tuples to avoid this problem. But I did not, and that lost me 20-30 minutes, changed the representation in Puzzle #1. So I spent a lot of time debugging Puzzle #2 only to later find out that the issue was the input. I gave Puzzle #2 the input after running Puzzle #1, and by then it was modified.

I fixed the problem by changing from lists to tuples. You can still use `+=`, it just does something else for tuples. For lists, `+=` will in-place modify the left-hand-side. For tuples, `+=`, is syntactic sugar for addition and an assignment, so you are assigning to a variable and not modifying an object. That was frustrating.

Anyway, the solution to Puzzle #2—that was working all along, it just needed the correct input—is not much more complex than Puzzle #1 (although deciphering the game description is).


```python
def play(p1, p2, states):
    while p1 and p2:
        if (p1,p2) in states:
            # player one wins
            return 1, p1
        states.add((p1,p2))

        card1,card2 = p1[0],p2[0]
        p1, p2 = p1[1:], p2[1:]

        winner = None
        if card1 > len(p1) or card2 > len(p2):
            winner = 1 if card1 > card2 else 2
        else:
            winner,_ = play(p1[:card1], p2[:card2], set())

        if winner == 1:    
            p1 += (card1,card2)
        else:
            p2 += (card2,card1)
        
    return (1,p1) if p1 else (2,p2)

_, winner = play(player1, player2, set())
result = sum((i+1)*x for i,x in enumerate(reversed(winner)))
print(f"Puzzle #2: {result}")
```

If the puzzles over Christmas are equally simple, I could get away with solving them there, and I would give it a try if I were that optimistic. I am not, however. I fear we will run into another Day 20 soon. And I know myself well enough to realise that I will not be able to let a puzzle go, so if I start, I will continue until I am done. It is best to stop now, and return in the New Year. That also gives me something to look forward to.
