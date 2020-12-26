+++
title = "Advent of Code 2020 — day 25"
date = 2020-12-25T07:01:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++

On the [last day of Christmas AoC gave to me](https://adventofcode.com/2020/day/25) an encryption problem, that is really a modular arithmetic problem.

If you decode the description—that is more cryptic than the mathematics—you find that we need to find secret keys by solving equations

$$7^k \equiv b \mod N$$

where \\(N = 20,201,227\\) and where \\(b\\) is part of our input (the public keys for a door and a card). Identify \\(k\\) and compute 
 
$$b_i^{k_j} \mod N$$
 
for public key \\(b_i\\) and secrete key \\(k_j\\), and you are done.

It is a nice little puzzle—perhaps the organisers realise how cruel it would be to make us spend hours on the Christmas Day with their puzzles—but I still managed to spend almost an hour on it.

I was trying to figure out an elegant way to solve the equation for \\(k\\), and I tried various things, but nothing seemed to work. I am going to call my pet number-theorist a little later in the day to hear if he knows how it is done.

When you can’t be smart, you can let the computer do the work, so I brute-forced a linear search for \\(k\\) and solved the equations that way.

When you work with Python integers, you don’t have to worry about overflow, so there is nothing wrong with taking the remainders of such equations after taking the powers, but it is *slow*.

Large integers are not as simple as those that fit into the computer’s registers, and you *really* pay for working with large numbers. It is not as much of a problem as when you work in a language with fixed-sized integers—where you get an overflow, and probably you don’t get a warning about it—but it does get terribly slow.

Thus, for the linear search, I updated the value on the left-hand side in each iteration, and for computing the final value, I used `pow()` with a third `mod` argument, instead of `x ** k` to compute the power. You will get the right result if you use the `**` operator and `%` after taking the power, but you will have to wait longer for it.


```python
N = 20201227

# Fuck this! I brute force it!
def solve_k(x, b): # Find k: x**k % N == b
    k = 0
    val = 1
    while True:
        if val == b: return k
        k += 1
        val = (val * x) % N

TEST_DATA = False
DOOR_PK = 17807724 if TEST_DATA else 3248366
CARD_PK = 5764801  if TEST_DATA else 4738476

CARD_SK = solve_k(7, CARD_PK)
DOOR_SK = solve_k(7, DOOR_PK)

# x ** k % N is too slow when the numbers get large,
# so we have to take the remainder along the way
ENCRYPTION_KEY = pow(DOOR_PK, CARD_SK, N)
print(f"Puzzle #1: {ENCRYPTION_KEY}")
```

There was no Puzzle #2. If you have all the stars, you get through to the credit. If you do not, you have to go back and collect all the starts you haven’t received yet to get the last star. So Puzzle #2 is either very quick today, or potentially very hard to get.

```python
print(f"Puzzle #2: Pay up! You have the stars!")
```

All in all, it was fun to do Advent of Code. It’s my first year, but I expect to do it again next year. Many of the challenges took me to places I haven’t been before. I’ve never worked with hexagonal grids, for example, and I have never had to work with rotations (and we had a few days where we had to play with that). So I learned a lot. I also learned a lot just from working with such small challenges, where you get the chance to play a lot more with the problems and with different ways of solving them.

All in all, I will recommend it.

I might go back and work through previous year’s puzzles as well at some point. But that will be on the other side of January’s exams and February’s book deadline.

Merry Christmas, everyone.

### Update 26th Dec 2020

{{< tweet 1342372049445130242 >}}

Yup, that is more elegant:

```python
TEST_DATA = False
DOOR_PK = 17807724 if TEST_DATA else 3248366
CARD_PK = 5764801  if TEST_DATA else 4738476

from sympy.ntheory import discrete_log
N = 20201227
def solve_k(a, b):
    return discrete_log(N, b, a)

CARD_SK = solve_k(7, CARD_PK)
ENCRYPTION_KEY = pow(DOOR_PK, CARD_SK, N)

print(f"Puzzle #1: {ENCRYPTION_KEY}")
print(f"Puzzle #2: Pay up! You have the stars!")
```

It is also faster. Around 700ms instead of three seconds with the brute force solution.

The stuff about k-root in my tweet is nonsens. I started out looking at it like that, and it stuck in my head after I realised that I was looking for a logarithm. It must still have been in my brain when I wrote the tweet.

It was pointed out to me that I shouldn’t expect a theoretically faster solution.

{{< tweet 1342616617461702657 >}}

A friend of mine told me that he did have an efficient algorithm for discrete logarithm once, but forgot to write it down. I hope he remembered to write down his notes for my upcoming C pointers book, because he is currently reviewing it…

