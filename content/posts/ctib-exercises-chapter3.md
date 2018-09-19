---
title: "Exercises (CT chapter 3)"
date: 2018-09-19T16:41:37+02:00
tags: [teaching, computational-thinking]
---

I have cleaned up the exercises for chapter three of [Introduction to Computational Thinking](https://leanpub.com/comp-thinking). I’m still not exactly sure how best to provide them to my students, or if I can figure out some way to automatically test answers so they can be more interactive, but I have listed them below. I have listed my answers below the exercises, so if you want to do the exercises, then stop in time.

As always, if you have comments or criticisms, or just suggestions for more exercises, I’m dying to hear.

## Below or above

Here's a game you can play with a friend: one of you think of a number between 1 and 20, both 1 and 20 included. The other has to figure out what that number is. He or she can guess at the number, and after guessing will be told if the guess is correct,  too high, or is too low. Unless the guess is correct, the guesser must try again until the guess *is* correct.

The game can be implemented like this:

```python
# The following code is just to setup the exercise. 
# You do not need to understand but can jump to the game below.

from numpy.random import randint
def input_integer(prompt):
    """Get an integer from the user."""
    while True:
        try:
            inp = input(prompt)
            i = int(inp)
            return i
        except:
            print(inp, "is not a valid integer.")


# Here is an implementation of the game. The computer picks
# a number and you should try to guess it.

# When picking a random number, we specify the interval
# [low,high). Since high is not included in the interval,
# we need to use 1 to 21 to get a random number in the
# interval [1,20].
n = randint(1, 21, size=1)

# Now, repeat guessing until we get the right number.
guess = input_integer("Make a guess> ")
while guess != n:
    if guess > n:
        print("Your guess is too high!")
    else:
        print("Your guess is too low!")
    guess = input_integer("Make a guess> ")
print("You got it!")
```


In this game, the computer gets to pick the number and you need to guess it.

Here are three different strategies you could use to guess the number:

1. Start with one. If it isn't the right number, it has to be too low--there are no smaller numbers the right one could be. So if it isn't one, you guess it is two. If it isn't, you have once again guessed too low, so now you try three. You continue by incrementing your guess by one until you get the right answer.
2. Alternatively, you start at 20. If the correct number is 20, great, you got it in one guess, but if it is not, your guess must be too high—it cannot possibly be too small. So you try 19 instead, and this time you work your way down until you get the right answer.
3. Tired of trying all numbers from one end to the other, you can pick this strategy: you start by guessing 10. If this is correct, you are done, if it is too high, you know the real number must be in the interval [1,9], and if the guess is too low, you know the right answer must be in the interval [11,20]—so for your next guess, you pick the middle of the interval it must be. With each new guess, you update the range where the real number can hide and choose the middle of the previous range.

**Exercise:** Prove that all three strategies terminate and with the correct answer, i.e. they are algorithms for solving this problem.

**Exercise:** Would you judge all three approaches to be equally efficient in finding the right number? If not, how would you order the three strategies such that the method most likely to get the correct number first is ranked highest, and the algorithm most likely to get the right number last is rated lowest. Justify your answer.

If you do not lie to the computer when it asks you about its guess compared to the number you are thinking of, this program implements the first strategy:

```python
# The following code is just to setup the exercise. You do not need to
# understand but can jump to the game below.


def input_selection(prompt, options):
    """Get user input, restrict it to fixed options."""
    modified_prompt = "{} [{}]: ".format(
        prompt.strip(), ", ".join(options)
    )
    while True:
        inp = input(modified_prompt)
        if inp in options:
            return inp
        # nope, not a valid answer...
        print("Invalid choice! Must be in [{}]".format(
            ", ".join(options)
        ))


# Here, we implement the computer's strategy for guessing
# the number you are thinking of. Don't lie to the
# computer. It won't punish you, but it will frown upon it.
for guess in range(1, 21):
    result = input_selection(
        "I'm guessing {}\nHow is my guess?".format(guess),
        ["low", "hit", "high"]
    )
    if result == "hit":
        print("Wuhuu!")
        break
    else:
        print("I must have been too low, right?", result)
```

**Exercise:** Implement the other two strategies and test them.

When iterating from 20 and down, for the second strategy, you should always get the result `"high"` when you ask about your guess, so you can use a `for` loop and not worry about the actual result form `input_selection`. When you implement strategy number three, however, you need to keep track of a candidate interval with a lower bound, initially 1, and an upper bound, initially 20. When you guess too high, you should lower your upper bound to the value you just guessed minus one (no need to include the guess we know is too high). When you guess to low, you must increase your lower bound to the number you just guessed plus one. In both cases, after updating the interval, you should guess for the middle point in the new range. When you compute the middle value in your interval, you can use 

```python
guess = int(upper_bound + lower_bound) / 2)
```



## Finding square roots

Given a positive number S > 0, we want to compute its positive square root, √S. We don't need our answer to be perfectly accurate. Using floating point numbers with a finite number of bits to represent the uncountable set of real numbers prevents this anyway. However, we want to be able to put an upper bound on the error we get, ε, such that we are guaranteed that for our result, S’, we have |S - S’| < ε.

One algorithm that solves this problem is known as the *Babylonian method* and is based on two observations. The first is this: for any x > 0, if x > √S then S/x < √S and if S/x > √S then x < √S, i.e., if we guess at a value for the square root of S and the guess is too high, we have a lower bound on what it *could* be, and if the guess is too low, we have an upper bound on what it could be.

To see that this is so, consider the case where x > √S and therefore x² > S. This inequality naturally also implies that S/x² < x²/x², and from this we derive S = S(x²/x²) > S(S / x²) = (S/x)², i.e., S/x < √S. The other case is proven similarly.

Because of this, if we start out knowing nothing about √S, it could be anywhere between 0 and S, so we can make an initial guess of some x₀ : 0 < x₀ < S. If |S - x₀| < ε, then x₀ is an acceptable output and we are done. If not, we know that √S lies in the interval (x/S,x) (if x² > S) or in the interval (x, x/s) (if x² < S), and we can make a new guess inside that interval.

The Babylonian method for finding square roots follows this idea and work as follows:

1. First, make a guess for x₀, e.g. x₀ = S/2. Any number in (0,S) will do.

2. Now, repeat the following, where we denote the guess we have at iteration i by xᵢ.

    1. If S/xᵢ - xᵢ| < ε report xᵢ.
    2. Otherwise, update xᵢ₊₁ = 1/2(xᵢ + S/xᵢ).
    

The test |S/xᵢ - xᵢ| < ε is different from the requirement we made about the error we would accept, which was |√S - xᵢ| < ε, but since we don't know √S we cannot test that directly. We know, however, that √S lies in the interval (S/x,x) or the interval (x,S/x), so if we make this interval smaller than ε, we have reached at least the accuracy we want.

The update xᵢ₊₁ = 1/2(xᵢ + S/xᵢ) picks the next guess to be the average of xᵢ and S/xᵢ, which is also the midpoint in the interval (S/x,x) (for x > S/x) or the interval (x,S/x) (for x < S/x), so inside the interval we know must contain √S.

**Exercise:** From this description alone you can argue that *if* the method terminates, it will report a correct answer. Prove that the algorithm is correct.

In each iteration, we update the interval in which we know √S resides by cutting the previous interval in half.

**Exercise:** Use this to prove that the algorithm terminates.

**Exercise:** Implement and test this algorithm.


## Changing base

When we write a number such as 123 we usually mean this to be in base 10, that is, we implicitly understand this to be the number 3 × 10⁰ + 2 × 10¹ + 1 × 10². Starting from the right and moving towards the left, each digit represents an increasing power of tens. The number *could* also be in octal, although then we would usually write it like 123₈. If the number were in octal, each digit would represent a power of eight, and the number should be understood as 3 × 8⁰ + 2 × 8¹ + 3 × 8².

Binary, octal and hexadecimal numbers—notation where the bases are 2, 8, and 16, respectively—are frequently used in computer science as they capture the numbers you can put in one, three and four bits. The computer works with bits, so it naturally speaks binary. For us humans, binary is a pain because it requires long sequences of ones and zeros for even relatively small numbers, and it is hard for us to readily see if we have five or six or so zeroes or ones in a row.

Using octal and hexadecimal is more comfortable for humans than binary, and you can map the digits in octal and hexadecimal to three and four-bit numbers, respectively. Modern computers are based on bytes (and multiples of bytes) where a byte is eight bits. Since a hexadecimal number is four bits, you can write any number that fits into a byte using two hexadecimal digits rather than eight binary digits. Octal numbers are less useful on modern computers, since two octal digits, six bits, are too small for a byte while three octal digits, nine bits, are too larger. Some older systems, however, were based on 12-bits numbers, and there you had four octal numbers. Now, octal numbers are merely used for historical reasons; on modern computers, hexadecimal numbers are better.

Leaving computer science, base 12, called duodecimal, has been proposed as a better choice than base 10 for doing arithmetic because 12 has more factors than 10 and this system would be simpler to do multiplication and division in. It is probably unlikely that this idea gets traction, but if it did, we would have to get used to converting old decimal numbers into duodecimal.

In this exercise, we do not want to do arithmetic in different bases but want to write a function that prints an integer in different bases.

When the base is higher than 10, we need a way to represent the digits from 10 and up. There are proposed special symbols for these, and these can be found in Unicode, but we will use letters, as is typically done for hexadecimal. We won't go above base 16 so we can use this table to map a number to a digit up to that base:

```python
digits = {}

for i in range(0,10):
    digits[i] = str(i)

digits[10] = 'A'
digits[11] = 'B'
digits[12] = 'C'
digits[13] = 'D'
digits[14] = 'E'
digits[15] = 'F'
```

To get the last digit in a number, in base `b`, we can take the division rest, the modulus, and map that using the `digits` table:

```python
digits[i % b]
```

Try it out.

You can extract the base b representation of a number by building a list of digits starting with the smallest. You can use `digits[i % b]` to get the last digit and remember that in a list. Then we need to move on to the next digit. Now, if the number we are processing is n = b⁰ × a_0 + b¹ × a₁ + b² × a₂ + … + b<sup>n</sup> a<sub>m</sub>, then a₀ is the remainder in a division by b and the digit we just extracted. Additionally, if // denotes integer division, n // b = b⁰ × a₁ + b¹ × a₂ + … b<sup>m-1</sup>a<sub>m</sub>. So, we can get the next digit by first dividing n by b and then extract the smallest digit.

If you iteratively extract the lowest digit and put it in a list and then reduce the number by dividing it by b, you should eventually have a list with all the digits, although in reverse order. If your list is named `lst`, you can reverse it using this expression `lst[::-1]`. The expression says that we want `lst` from the beginning to the end—the default values of a range when we do not provide anything—in steps of minus one.

**Exercise:** Flesh out an algorithm, based on the observations above, that can print any integer in any base b <= 16. Show that your method terminates and outputs the correct string of digits.


## Sieve of Eratosthenes

The [Sieve of Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes) is an early algorithm for computing all prime numbers less than some upper bound n. It works as follows: we start with a set of candidates for numbers that could be primes, and since we do not a priori know which numbers will be primes we start with all the natural numbers from two and up to n.

```python
candidates = list(range(2, n + 1))
```

We are going to figure out which are primes by elimination and put the primes in another list that is initially empty.

```python
primes = []
```

The trick now is to remove from the candidates the numbers we know are not primes. We will require the following loop invariants:

1. All numbers in `primes` are prime.
2. No number in `candidates` can be divided by a number in `primes`.
3. The smallest number in `candidates` is a prime.

**Exercise:** Prove that the invariants are true with the initial lists defined as above.

We will now loop as long as there are candidates left. In the loop, we take the smallest number in the `candidates` list, which by the invariant must be a prime. Call it p. We then remove all candidates that are divisible by p and then add p to `primes`.

**Exercise:** Prove that the invariants are satisfied after these steps whenever they are satisfied before the steps.

**Exercise:** Prove that this algorithm terminates and is correct, i.e., that `primes` once the algorithm terminates contain all primes less than or equal to n. Correctness does not follow directly from the invariants so you might have to extend them.

**Exercise:** Implement and test this algorithm.


## Longest increasing substring

Assume you have a list of numbers, for example

```python
x = [12, 45, 32, 65, 78, 23, 35, 45, 57]
```

**Exercise:** Design an algorithm that finds the longest sub-sequence `x[i:j]` such that consecutive numbers are increasing, i.e. `x[k] < x[k+1]` for all `k` in `range(i,j)`  (or one of the longest, if there are more than one with the same length).

*Hint:* One way to approach this is to consider the longest sequence seen so far and the longest sequence up to a given index into `x`. From this, you can formalise invariants that should get you through.

## Computing power-sets


The *powerset* P(S) of a set S is the set that contains all possible subsets of S. For example, if S={a,b,c}, then 

P(S) = {∅, {a}, {b}, {c}, {a,b}, {a,c}, {b,c}, {a,b,c} }

**Exercise:** Assume that S is represented as a list. Design an algorithm that prints out all possible subsets of S. Prove that it terminates and is correct.

*Hint:* You can solve this problem by combining the numerical base algorithm with an observation about the binary representation of a number and a subset of S. We can represent any subset of S by the indices into the list representation of S. Given the indices, just pick out the elements at those indices. One way to represent a list of indices is as a binary sequence. The indices of the bits that are 1 should be included, the indices where the bits are 0 should not. If you can generate all the binary vectors of length `n = len(S)`, then you have implicitly generated all subsets of S. You can get all these bit vectors by getting all the numbers from zero to 2ⁿ and extracting the binary representation.


## Longest increasing subsequence

Notice that this problem has a different name than "longest increasing *substring*"; it is a slightly different problem. Assume, again, that you have a list of numbers. We want to find the longest sub-sequence of increasing numbers, but this time we are not looking for consecutive indices `i:j`, but a sequence of indices i₀,i₁,…,i<sub>m</sub> such that i<sub>k</sub> < i<sub>k + 1</sub>  and x[i<sub>k</sub>] < x[i<sub>k+1</sub>].

**Exercise** Design an algorithm for computing the longest (or a longest) such sequence of indices i₀,i₁,…,i<sub>m</sub>.

*Hint:* This problem is harder than the previous one, but you can brute force it by generating *all* subsequences and checking if the invariant is satisfied. This is a *very* inefficient approach, but we need to learn a little more about algorithms before we will see a more efficient solution.

## Merging

Assume you have two sorted lists, `x` and `y`, and you want to combine them into a new sequence, `z`, that contains all the elements from `x` and all the elements from `y`, in sorted order. You can create `z` by *merging* `x` and `y` as follows: have an index, `i`, into `x` and another index, `j`, into `y`—both initially zero—and compare `x[i]` to `y[j]`. If `x[i] < y[j]`, then append `x[i]` to `z` and increment `i` by one. Otherwise, append `y[j]` to `z` and increment `j`. If either `i` reaches the length of `x` or `j` reaches the end of `y`, simply copy the remainder of the other list to `z`.

**Exercise:** Argue why this approach creates the correct `z` list and why it terminates.

# Answers

## Below or above

**Exercise:** Prove that all three strategies terminate and with the correct answer, i.e. they are algorithms for solving this problem.

**Answer:** For 1: If you let `i` denote the current number you are considering, then 20 - `i` is your termination function. You never skip a number, so when you will eventually see all numbers between 1 and 20 and you will be told when you saw the right one.

**Answer:** For 2: Here you can use `i` - 1 as your termination function (minus one to make the termination function hit zero at the last number we consider). The argument for correctness is the same as before.

**Answer:** For 3: For termination we can use high - low. This interval is shrinking in each iteration and will eventually be empty. Before it is empty, though, we must have hit an interval of length 1 that contains the number we are looking for. Why? Because whenever `high - low > 2`, both `mid - low` and `high - low` >= 2 and when `high - low == 2` we have `mid = low` and either we have found the element at `mid` or the element is at `mid + 1` (since it must be in the interval) and the next recursion has an interval of length one where the element we are searching for is at the front.

**Exercise:** Would you judge all three approaches to be equally efficient in finding the right number? If not, how would you order the three strategies such that the method most likely to get the right number first is ranked highest and the algorithm most likely to get the right number last is ranked lowest. Justify your answer.

**Answer:** In the first two strategy we eliminate one element at a time until we find the one we are searching for. In the third strategy we eliminate half the remaining interval in each iteration. We would therefore expect the third strategy to be faster than the first two.

If you do not lie to the computer when it asks you about its guess compared to the number you are thinking of, this program implements the first strategy:

```python
# The following code is just to setup the exercise.
# You do not need to understand but can jump to the game below.

def input_selection(prompt, options):
    """Get user input, restrict it to fixed options."""
    modified_prompt = "{} [{}]: ".format(
        prompt.strip(), ", ".join(options)
    )
    while True:
        inp = input(modified_prompt)
        if inp in options:
            return inp
        # nope, not a valid answer...
        print("Invalid choice! Must be in [{}]".format(
            ", ".join(options)
        ))

# Here, we implement the computer's strategy for guessing
# the number you are thinking of. Don't lie to the
# computer. It won't punish you, but it will frown upon it.
for guess in range(1, 21):
    result = input_selection(
        "I'm guessing {}\nHow is my guess?".format(guess),
        ["low", "hit", "high"]
    )
    if result == "hit":
        print("Wuhuu!")
        break
    else:
        print("I must have been too low, right?", result)
```

**Exercise:** Implement the other two strategies and test them.

**Answer:** Counting down from 20 to 1 can be implemented like this:

```python
for guess in range(20,0,-1):
    result = input_selection(
        "How is my guess {}?".format(guess), 
        ["low", "hit", "high"]
    )
    if result == "hit":
        print("Wuhuu!")
        break
    else:
        print("I must have been too hight, right? ", result)
```

**Answer:** Cutting the interval in half in each iteration can be implemented like this:

```python
lower_bound = 1
upper_bound = 20
while True:
    guess = (upper_bound + lower_bound) // 2
    result = input_selection(
        "How is my guess {}?".format(guess),
        ["low", "hit", "high"]
    )
    if result == "hit":
        print("Wuhuu!")
        break
    elif result == "low":
        lower_bound = guess + 1
    else:
        upper_bound = guess - 1
```


## Finding square roots

**Exercise:** From the description alone you can argue that *if* the method terminates, it will report a correct answer. Prove that the algorithm is correct.

**Answer:** We only terminate when |S/xᵢ - xᵢ|< ε. We know that if xᵢ < S/xᵢ then xᵢ_i ≤ x < S/xᵢ, so xᵢ is within ε of the true value, x. If xᵢ > S/xᵢ we know that S/xᵢ < x ≤ xᵢ, and again we know that xᵢ is within ε\ of the true value, x.

In each iteration, we update the interval in which we know √S resides by cutting the previous interval in half.

**Exercise:** Use this to prove that the algorithm terminates.

**Answer:** We can use |S/xᵢ - xᵢ - ε as our termination function. Each iteration decreases the |S/xᵢ - xᵢ| by one half, so the size of the interval moves asymptotically towards zero. This means that eventually it will be smaller than any ε, so the algorithm must terminate.

**Exercise:** Implement and test this algorithm.

```python
lower_bound = 0
upper_bound = S
x = upper_bound / 2
while (upper_bound - lower_bound) > ε:
    x = (lower_bound + upper_bound) / 2
    if x**2 > S:
        lower_bound = S/x
        upper_bound = x
    else:
        lower_bound = x
        upper_bound = S/x
```

You can use this as a test run:

```python
from math import sqrt

# let us compute the square root of 2 within 
# an accuracy of one in a hundred thousands
S = 2
ε = 1e-5

lower_bound = 0
upper_bound = S
x = upper_bound / 2
while (upper_bound - lower_bound) > ε:
    x = (lower_bound + upper_bound) / 2
    if x**2 > S:
        lower_bound = S/x
        upper_bound = x
    else:
        lower_bound = x
        upper_bound = S/x


print("We expect to agree on the first four decimals,")
print("since these are in ten-thousands, but not necessarily")
print("at the fifth decimal, which is below our precision.\n")
print("Results:")
print("Python suggests {:.5f}".format(sqrt(2)))
print("Babylonian method gave us {:.5f}".format(x))
```

## Changing base

My implementation looks like this:

```python
digits = {}

for i in range(0,10):
    digits[i] = str(i)

digits[10] = 'A'
digits[11] = 'B'
digits[12] = 'C'
digits[13] = 'D'
digits[14] = 'E'
digits[15] = 'F'

m = 32

b = 16
base_b = []
n = m
while n > 0:
    base_b.append(digits[n % b])
    n //= b
print(m, "in base", b, "is", "".join(base_b[::-1]))

b = 10
n = m
base_b = []
while n > 0:
    base_b.append(digits[n % b])
    n //= b
print(m, "in base", b, "is", "".join(base_b[::-1]))


b = 8
n = m
base_b = []
while n > 0:
    base_b.append(digits[n % b])
    n //= b
print(m, "in base", b, "is", "".join(base_b[::-1]))

b = 4
n = m
base_b = []
while n > 0:
    base_b.append(digits[n % b])
    n //= b
print(m, "in base", b, "is", "".join(base_b[::-1]))

b = 2
n = m
base_b = []
while n > 0:
    base_b.append(digits[n % b])
    n //= b
print(m, "in base", b, "is", "".join(base_b[::-1]))
```

## Sieve of Eratosthenes

I will require the following loop invariants:

1. All numbers in `primes` are prime.
2. No number in `candidates` can be divided by a number in `primes`.
3. The smallest number in `candidates` is a prime.

**Exercise:** Prove that the invariants are true with the initial lists defined as above.

**Answer:** Any properties we care to require about the elements in an empty list are true. There are no elements for which they can be false. We call this *vacuously* true.

We will now look as long as there are candidates left. In the loop, we take the smallest number in the `candidates` list, which by the invariant must be a prime. Call it $p$. We then remove all candidates that are divisible by $p$ and then add $p$ to `primes`.

**Exercise:** Prove that the invariants are satisfied after these steps whenever they are satisfied before the steps.

**Answer:** If the front element in `candidates` was divisible by any smaller number—and we only care about smaller numbers when we consider the divisible property—then it would have been removed. It isn’t divisible by a smaller number, it must therefore be prime. When we move it to `primes` we satisfy the invariant for that list. Let `p` be the first number in `candidates` before we move it to `primes`. In `candidates`, before we remove those divisible by `p`, we have no numbers that are divisible by any of the smaller primes. We explicitly remove those divisible by `p`. We are then left with numbers that are not divisible by any of the numbers in `primes`.

**Exercise:** Prove that this algorithm terminates and is correct, i.e., that `primes` once the algorithm terminates contain all primes less than or equal to $n$. Correctness does not follow directly from the invariants, so you might have to extend them.

**Answer:** For a termination function we can use the length of the `candidates` list. It is decreased by at least one every iteration, because we move its first element to `primes`, and we terminate when it is empty. Where the invariants come up short is that they tell us that `primes` are all primes, as is `candidates[0]` when `candidates` is not empty, but they do not tell us that `primes` eventually will contain *all* the primes less than $n$. To get to there, we can modify the invariants to say that `primes` contain all primes less than `candidates[0]` when `candidates` is not empty or $n$ when it is. You can prove that this invariant is also true very similarly to how we proved the other invariants. When you have a prime in `p = candidates[0]`, `primes` contain all smaller primes (by the invariant). When we move `p` to `primes` the invariant is also true—`primes` still contain all primes less than `p`, this doesn’t change when we add `p`. From `candidates` we now remove numbers that are *not* prime, but never numbers that are. We end up with either a new `p = candidates[0]` that must be a larger prime, so we can repeat the argument for the next iteration, or we end up with an empty list. When we have an empty list we have evaluated all numbers up to and including $n$, and `primes` contain all the primes in that sequence.

**Exercise:** Implement and test this algorithm.

Here’s my solution:

```python
candidates = list(range(2, n+1))
primes = []
while len(candidates) > 0:
    p = candidates[0]
    candidates = [m for m in candidates if m % p != 0]
    primes.append(p)
```

Pick `n` and try it out.


## Longest increasing substring

My implementation looks like this:

```python

x = [12, 45, 32, 65, 78, 23, 35, 45, 57]
# We can always have a longest sequence containing just the first character
longest_from, longest_to, longest_len = 0, 1, 1

# Brute force solution
for i in range(len(x)):
	for j in range(i + 1, len(x)):
		if x[j] <= x[j - 1]:
			break
	if j - i > longest_len:
		longest_from, longest_to, longest_len = i, j, j - i

print(longest_from, longest_to, x[longest_from:longest_to])

# Linear time solution
longest_from, longest_to, longest_len = 0, 1, 1
current_from = 0
for i in range(1, len(x)):
	# the current interval is [current_from, i)
	if x[i - 1] >= x[i]:
		# we have to start a new interval
		current_len = i - 1 - current_from
		if current_len > longest_len:
			longest_from, longest_to, longest_len = current_from, i, current_len
		# start new interval
		current_from, current_len = i, 1

print(longest_from, longest_to, x[longest_from:longest_to])
```

## Computing power-sets

The hint tells you that there is a close correspondence between the powers of a set, S, and the binary representation of all the numbers from zero to `len(S)`.

Consider this program:

```python
n = 3
m = 2**n
for i in range(m):
	reverse_bits = [0] * n
	k = 0
	while i > 0:
		reverse_bits[k] = i % 2
		i //= 2
		k += 1
	print(reverse_bits[::-1])
```

It is a slight variation on the program from the chapter that gets the binary representation of a number. This variant always have n (binary) digits, which the algorithm in the chapter does not, but otherwise it is the same.

If you run it with n equal to three, as in the code listing above, you get the output

```
[0, 0, 0]
[0, 0, 1]
[0, 1, 0]
[0, 1, 1]
[1, 0, 0]
[1, 0, 1]
[1, 1, 0]
[1, 1, 1]
```

If you extract, from the list S, the indices where the bit is set, you get subsets of S, and if you extract the sets for each of these lists you have the power-set of S.

```python
S = ['a', 'b', 'c']
powS = []

print("powerset of", S)
n = len(S)
m = 2**n
for i in range(m):
	j = 0
	x = []
	while i > 0:
		if i % 2 == 1:
			x.append(S[j])
		i //= 2
		j += 1
	print(x)
	powS.append(x)
print()

print("powS =", powS)
```

## Longest increasing subsequence

My solution is this implementation (I explain it below):

```python
x = [12, 45, 32, 65, 78, 23, 35, 45, 57]

# best so far
best_indices = []

# Set up for computing all combination of indices
n = len(x)
m = 2**n
for i in range(m):
	# collect indices
	j = 0
	indices = []
	while i > 0:
		if i % 2 == 1:
			indices.append(j)
		i //= 2
		j += 1

	# check if indices gives us an increasing sequence
	for k in range(1, len(indices)):
		prev, this = indices[k-1], indices[k]
		if x[prev] >= x[this]:
			# not increasing, so break
			break
	else:
		# the else part of a for-loop is executed
		# when we leave it by ending the loop
		# and not when breaking...
		if len(indices) > len(best_indices):
			best_indices = indices

vals = [x[i] for i in best_indices]
print("increasing sequence:", best_indices, vals)


for i in range(m):
	# collect indices
	j = 0
	indices = []
	while i > 0:
		if i % 2 == 1:
			indices.append(j)
		i //= 2
		j += 1

	# check if indices gives us an increasing sequence
	increasing = True
	for k in range(1, len(indices)):
		prev, this = indices[k-1], indices[k]
		if x[prev] >= x[this]:
			# not increasing, so break
			increasing = False
			break
	if increasing:
		# the else part of a for-loop is executed
		# when we leave it by ending the loop
		# and not when breaking...
		if len(indices) > len(best_indices):
			best_indices = indices

vals = [x[i] for i in best_indices]
print("increasing sequence:", best_indices, vals)
```

We start by defining some variables to hold the best sequence we have seen so far.

```python
best_indices = []
```

We do not keep track of the length; we can always get that from `len(best_indices)`.

Now we take the same approach as for computing power-sets. If we get the power-set of indices using the algorithm from the previous exercise, then we get the indices in increasing order.

```python
# Set up for computing all combination of indices
n = len(x)
m = 2**n
for i in range(m):
	# collect indices
	j = 0
	indices = []
	while i > 0:
		if i % 2 == 1:
			indices.append(j)
		i //= 2
		j += 1

	# check if indices gives us an increasing sequence
	# …
```

This code iterates through all sets of increasing indices. We can examine each in turn and test that these indices give us an increasing sequence of x values. We can simply run through the list of indices and check that each one index a value in x that is larger than the previous one. If not, we break the loop.

```python
	# check if indices gives us an increasing sequence
	for k in range(1, len(indices)):
		prev, this = indices[k-1], indices[k]
		if x[prev] >= x[this]:
			# not increasing, so break
			break
```

The `break` only leaves the inner-most `for`-loop, but we actually want to leave the outermost loop—we want to move on to the next candidate list of indices.

We can use a boolean flag to help us out here. We set it to `True`, but if the candidate list of indices do not describe an increasing subsequence, then we set it to `False`. Only if it is `True` do we potentially update the best sequence.

```python
	# check if indices gives us an increasing sequence
	increasing = True
	for k in range(1, len(indices)):
		prev, this = indices[k-1], indices[k]
		if x[prev] >= x[this]:
			# not increasing, so break
			increasing = False
			break
	if increasing:
		# the else part of a for-loop is executed
		# when we leave it by ending the loop
		# and not when breaking...
		if len(indices) > len(best_indices):
			best_indices = indices
```

There is actually another way to implement this. We haven’t seen this before, but loops have an `else` part, just as `if`-statements. They just behave very differently, and the name `else` is probably more confusing than the feature it implements. A keyword such as `completed` would be a better description.

The `else` block of a loop is executed if you leave the loop by running it to completion, i.e. if you run through all the elements in a `for`-loop or until the condition in a `while`-loop is `False`. the `else` block is *not* executed if you break from a loop.

So we can implement the validation of indices and the potential update of the best sequence seen so far as this:

```python
	# check if indices gives us an increasing sequence
	for k in range(1, len(indices)):
		prev, this = indices[k-1], indices[k]
		if x[prev] >= x[this]:
			# not increasing, so break
			break
	else:
		# the else part of a for-loop is executed
		# when we leave it by ending the loop
		# and not when breaking...
		if len(indices) > len(best_indices):
			best_indices = indices
```

When you are done, you can output the indices and corresponding values like this:

```python
vals = [x[i] for i in best_indices]
print("increasing sequence:", best_indices, vals)
```

## Merging

To make the algorithm concrete, I will list it as I would implement it:

```python
n, m = len(x), len(y)
i, j = 0, 0
z = []

while i < n and j < m:
	if x[i] < y[j]:
		z.append(x[i])
		i += 1
	else:
		z.append(y[j])
		j += 1

if i < n:
	z.extend(x[i:])
if j < m:
	z.extend(y[j:])
```

You can find this implementation in [merge.py](merge.py).

Now, let us prove termination and correctness…

### Termination

Termination is the easiest to handle. Let `n = len(x)` and `m = len(y)`, then the termination function is `t(i,n,j,m) = (n-i) + (m-j)`. In each iteration we either increase `i` by one or we increase `j` by one; in either case we decrease `t(i,n,j,m)` by one. 

We never actually reach zero with this termination function, we will leave the loop when *either* `i == n` or `j == m`, but *if* we reached zero, then the loop-condition would be false, so `t` works as a termination function.

### Correctness

The pre-condition for the loop is that `x` and `y` are sorted. We will use the invariant that `z` contains the elements in `x[:i]` and `y[:j]` in sorted order. NB: with this slicing notation, `i` and `j` are *not* included in the slices, so `x[i]` and `y[j]` are not yet in `z`.

If we only left the loop when `i == n` and `j == m`, then that would suffice to guarantee that `z` would end up containing the merged lists. We break when *either* of these two conditions are met, so we need the invariant to say a bit more—and this bit more also makes it easier to show that it holds true at the end of each loop-iteration.

We will require that `z` contains the elements in `x[:i]` and `y[:j]` in sorted order *and* that `z[k-1] <= min(x[i:],y[j:])`. Since `x` and `y` are sorted, this means that we can append either `x[i]` or `y[j]` to `z` (if these exist) and still have a sorted list. It also means that when `x[i:]` is empty we can extend `z` with the elements in `y[j:]` and vice versa, that when `y[j:]` is empty we can extend `z` with `x[:i]`. So, if we guarantee this invariant for the loop, we are guaranteed that when we break the loop we have sorted items from `x[:i]` and `y[:j]`, and if we append the missing elements (from either `x[i:]` or `y[j:]`) then we still have a sorted list, and this list will now contain all the elements from `x` and `y`.

To see that the invariant holds true, consider the two cases in the loop:
1. `x[i] < y[j]`: Here, we append `x[i]` to `z` and increase `i`. Since the invariant tells us that `z[k-1] <= x[i]` we get a sorted list from this, and since `x[i] <= x[i+1]` (when `i < n`, since `x` is sorted) and `x[i] < y[j]`, we have `z[k] <= min(x[i+1:],y[j:])` so we satisfy the invariant.
2. `else` (which means `x[i] >= y[j]`): The invariant tells us that we can append `y[j]` to `z` and still have a sorted list. For the new `z[k] == y[j]` we then have `z[k] <= x[i]` (from the `if`-condition) and `z[k] <= y[j+1]` (because `y` is sorted), so we satisfy the invariant once more.

<hr/>
<small>If you liked what you read, and want more like it, consider supporting me at [Patreon](https://www.patreon.com/mailund).</small>
<hr/>
