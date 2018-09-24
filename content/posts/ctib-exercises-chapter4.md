---
title: "Exercises (CT chapter 4)"
date: 2018-09-24T07:19:28+02:00
tags: [teaching, computational-thinking]
---

I think I’m done with the exercises for chapter 4 of [*Introduction to Computational Thinking*](https://leanpub.com/comp-thinking). Which is good, because I need to put them on Blackboard for my students this week.

I still haven’t figured out the best way to put the exercises on Blackboard. It is a truly awful system. It has as WYGIWYG (what you get is what you get) editor; the text while you edit it seems unrelated to the text it will display after you save it. It *really* dislike code; you can put code in pre-tags (or tell the editor to), but it considers that merely a suggestion that it can, and will, ignore at its leisure.

I got around the problem last class by writing text in Markdown, translate it into HTML using Pandoc, and then paste it into Blackboard. As long as I never attempted to edit the text after I pasted it in, it seemed to work.

I don’t know if I can get that to work with syntax highlighting in code-blocks, though. That requires that I add to the CSS, which I, a) don’t know how to, b) wouldn’t expect Blackboard to respect anyway.

I could also just link to GitHub where the exercises are, and where the Markdown files are rendered well. But Blackboard is very reluctant to let people click their way out of it—it opens a window when you click on a link and then you have to click another link there.

Most likely, I will just accept that Blackboard will be ugly and go for the `Markdown -> Pandoc -> paste HTML` solution.

Anyway, exercises and answers below. Let me know if you spot any mistakes!

# Exercises

## Counting primitive operations

**Exercise:** Consider this way of computing the mean of a sequence of numbers:

```python
accumulator = 0
for n in numbers:
	accumulator += n
mean = accumulator / len(numbers)
```

Count how many primitive operations it takes. To do it correctly you need to distinguish between updating a variable and assigning a value to a new one. Updating the accumulator `accumulator += n` usually maps to a single operation on a CPU because it involves changing the value of a number that is most likely in a register. Assigning to a new variable, as in

```python
mean = accumulator / len(numbers)
```

doesn’t update `accumulator` with a new value, rather it needs to compute a division, which is one operation (and it needs `len(numbers)` before it can do this, which is another operation), and then write the result in a new variable, which is an additional operation.

**Exercise:** Consider this alternative algorithm for computing the mean of a sequence of numbers:

```python
accumulator = 0
length = 0
for n in numbers:
	accumulator += n
	length += 1
mean = accumulator / length
```

How many operations are needed here? Is it more or less efficient than the previous algorithm?


## Guessing-game complexity


Recall the guessing game from the previous chapter, where one player thinks a number between 1 and 20 and the other has to guess it. We had three strategies for the guesser:

1. Start with one. If it isn't the right number, it has to be too low—there are no smaller numbers the right one could be. So if it isn't one, you guess it is two. If it isn't, you have once again guessed too low, so now you try three. You continue by incrementing your guess by one until you get the right answer.
2. Alternatively, you start at 20. If the right number is 20, great, you got it in one guess, but if it is not, your guess must be too high—it cannot possibly be too small. So you try 19 instead, and this time you work your way down until you get the right answer.
3. The third strategy is this: you start by guessing ten. If this is correct, you are done, if it is too high, you know the real number must be in the range [1,9], and if the guess is too low, you know the right answer must be in the range [11,20]—so for your next guess, you pick the middle of the range it must be. With each new guess, you update the interval where the real number can be hidden and pick the middle of the new range.

**Exercise:** Identify the best- and worst-case scenarios for each strategy and derive the best-case and worst-case time usage.


## Function growth

Consider the classes 

1. O(log n), o(log n), Ω(log n) and ⍵(log n)
3. O(n), o(n), Ω(n), and ⍵(n)
4. O(n²), o(n²), Ω(n²), and ⍵(n²)
5. O(2ⁿ), o(2ⁿ), Ω(2ⁿ), ⍵(2ⁿ)

**Exercise:** For each of the functions below, determine which of the 16 classes it belongs in. Remember that the complexity classes overlap, so for example, if f ∈ o(g) then f ∈ O(g) as well, and if f ∈ Θ(g) then f ∈ O(g) as well as Ω(g) (but f ∉ o(g) and f ∉ ⍵(g)).

1. f(n) = 23 × n
2. f(n) = 42 × n² - 100 × n
3. f(n) = n / log(n)
4. f(n) = log(n) / n
5. f(n) = n²/log(n)
6. f(n) = log(n) + log(n)/n
7. f(n) = 5ⁿ - n³
8. f(n) = n!
9. f(n) = 2ⁿ/n
10. f(n) = log(log(n))



## Insertion sort

Consider the insertion sort algorithm. We argued that the worst-case running time was O(n²) but the best-case running time was O(n).

**Exercise:** Describe what the input data, `numbers`, should look like to actually achieve the worst- and best-case running times.


## Binary search

We argued that the worst-case running time for the binary search is O(log n).

**Exercise:** What is the best-case running time, and what would the input data look like to achieve it?



## Sieve of Eratosthenes

Recall the Sieve of Eratosthenes from the previous chapter. 

**Exercise:** Derive an upper bound for its running time. 

**Exercise:** Is there a difference between its best-case and worst-case running time?


## Merging

Recall the *merging* algorithm from the previous chapter.

**Exercise:** Show that you can merge two sorted lists of size n and m, respectively, into one sorted list containing the elements from the two, in time O(n+m).

# Answers


## Counting primitive operations

### Exercise

Consider this way of computing the mean of a sequence of numbers:

```python
accumulator = 0
for n in numbers:
	accumulator += n
mean = accumulator / len(numbers)
```

Count how many primitive operations it takes. To do it correctly you need to distinguish between updating a variable and assigning a value to a new one. Updating the accumulator `accumulator += n` usually maps to a single operation on a CPU because it involves changing the value of a number that is most likely in a register. Assigning to a new variable, as in

```python
mean = accumulator / len(numbers)
```

doesn’t update `accumulator` with a new value, rather it needs to compute a division, which is one operation (and it needs `len(numbers)` before it can do this, which is another operation), and then write the result in a new variable, which is an additional operation.

### Answer

```python
accumulator = 0                      # 1
for n in numbers:                    # 5 × n + 2
	accumulator += n                 # n × 1
mean = accumulator / len(numbers)    # 3
```

so (5 + 1) × n + (1 + 2 + 3) =  6 × (n + 1).

### Exercise

Consider this alternative algorithm for computing the mean of a sequence of numbers:

```python
accumulator = 0
length = 0
for n in numbers:
	accumulator += n
	length += 1
mean = accumulator / length
```

How many operations are needed here? Is it more or less efficient than the previous algorithm?

```python
accumulator = 0                  # 1
length = 0                       # 1
for n in numbers:                # 5 × n + 2
	accumulator += n             # 1 × n
	length += 1                  # 1 × n
mean = accumulator / length      # 3
```

This implementation uses (5 + 1 + 1) × n + (1 + 1 + 2 + 3) = 7 × (n + 1). It is less efficient.



## Guessing-game complexity

**Exercise:** Identify the best- and worst-case scenarios for each strategy and derive the best-case and worst-case time usage.

### Answer

For the first strategy, the best case is when 1 is the value we are looking for and the worst case is when it is 20. The best-case and worst-case running times are O(1) and O(n).

For the second strategy, the best case is when we are looking for 20 and the worst case is when we are looking for 1. The best- and worst-case running times are O(1) and O(n).

For the third strategy, the best case is if we are looking for 10 (the first mid-point). In that case the running time is O(1). The worst case is when the value we are searching for is not the mid-point until there is only one element left. There are many ways that this can happen, but in all case we find the value in time O(log n), which is the worst-case complexity. We get this running time because we remove half of the range in each iteration, and if we remove half the elements in each iteration we cannot have more than log₂ n iterations before there is only one element left.


## Function growth

Classes 

1. O(log n), o(log n), Ω(log n) and ⍵(log n)
3. O(n), o(n), Ω(n), and ⍵(n)
4. O(n²), o(n²), Ω(n²), and ⍵(n²)
5. O(2ⁿ), o(2ⁿ), Ω(2ⁿ), ⍵(2ⁿ)

Functions:

1. f(n) = 23 × n
	1. Ω(log n) and ⍵(log n)
	2. O(n) and Ω(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)

2. f(n) = 42 × n² - 100 × n
	1. Ω(log n) and ⍵(log n)
	2. Ω(n) and ⍵(n)
	3. O(n²) and Ω(n²)
	4. O(2ⁿ) and o(2ⁿ)

3. f(n) = n / log(n)
	1. Ω(log n) and ⍵(log n)
	2. O(n), o(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)

4. f(n) = log(n) / n
	1. O(log n) and o(log n)
	2. O(n) and o(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)

5. f(n) = n²/log(n)
	1. Ω(log n) and ⍵(log n)
	2. Ω(n), and ⍵(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)

6. f(n) = log(n) + log(n)/n
	1. O(log n) and Ω(log n)
	2. O(n) and o(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)

7. f(n) = 5ⁿ - n³
	1. Ω(log n) and ⍵(log n)
	2. Ω(n) and ⍵(n)
	3. Ω(n²) and ⍵(n²)
	4. Ω(2ⁿ) and ⍵(2ⁿ)

8. f(n) = n!
	1. Ω(log n) and ⍵(log n)
	2. Ω(n) and ⍵(n)
	3. Ω(n²) and ⍵(n²)
	4. Ω(2ⁿ) and ⍵(2ⁿ)

9. f(n) = 2ⁿ/n
	1. Ω(log n) and ⍵(log n)
	2. Ω(n) and ⍵(n)
	3. Ω(n²) and ⍵(n²)
	4. O(2ⁿ) and o(2ⁿ)

10. f(n) = log(log(n))
	1. O(log n) and o(log n)
	2. O(n) and o(n)
	3. O(n²) and o(n²)
	4. O(2ⁿ) and o(2ⁿ)



## Insertion sort

**Exercise:** Describe what the input data, `numbers`, should look like to actually achieve the worst- and best-case running times.

**Answer:** 

Recall that the algorithm looks like this:

```python
for i in range(1,len(x)):
	j = i
	while j > 0 and x[j-1] > x[j]:
		x[j-1], x[j] = x[j], x[j-1]
		j -= 1		
```

For each index `i` we move the element there down until we find its place in the sorted part of `x`.

If `x` is sorted from the start, we never move an element down—we just discover that it is already where it should be. In that case, we get the linear running time.

If the elements are sorted but in the reverse order, however, each new value will be moved through all the sorted elements. In that case, we get the quadratic running time.


## Binary search

**Exercise:** What is the best-case running time, and what would the input data look like to achieve it?

**Answer:** If the very first element we see is the one we are looking for, i.e. if it at the midpoint of the range, then we finish in constant time.

## Sieve of Eratosthenes

**Exercise:** Derive an upper bound for its running time. 

**Answer:** For each i=1,…,n we potentially iterate through all larger numbers j=i+1,…n. On average this means that we iterate through n/2 numbers for each i, so an upper bound is O(n²).

**Exercise:** Is there a difference between its best-case and worst-case running time?

**Answer:** We do not *actually* iterate through all numbers larger than i. Only those that we have not eliminated as divisible by a number smaller than i. Getting the average number of elements left in the list when we look at prime p is not so straightforward; at least not to me. But we can give it the old college try.

When p=2, we run through n-1 elements—we have all but the first to run through. After that, there are n/2 left. Then, for three we run though those n/2, but we remove every third, so now there are no more than n/3 left. We do not remove a third of those that were left after removing the even numbers—it is not a third of those that are divisible by three—but there can’t be more than a third left of the original list when we have removed those divisible by three. The same argument then goes for p = 5; there can’t be more than a fifth of the original numbers left after that.

We can therefor bound the numbers of elements left after we have processed prime p by n/p. 

You can run this to see how n/p compares to the actual numbers:

```python
n = 100
numbers = list(range(2,n))
p = 1
while numbers != []:
	fmt = "#numbers = {:>2}, n/p = {:>3.2f}"
	print(fmt.format(len(numbers), n/p))
	p = numbers[0]
	numbers = [n for n in numbers if n % p != 0]
```

So, an upper bound of the algorithm is O(n + n/2 + n/3 + n/5 + … ) or O(n + n × (sum of 1/p for primes less than n).

The sum here is called the "sum of reciprocals of primes", and this [can be proven](https://bit.ly/2I8cdOH) to be in O(log(log(n)).

So, a tighter bound on the running time is O(n × log(log(n)) ).


## Merging

I don’t know how you implemented the merge algorithm, but my solution looks like this:

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

The two `extend` calls run in linear time (you have to trust me that it does; it is built into Python’s list implementation). So we only need to concern ourselves with the `while`-loop. Here, the body of the loop runs in constant time—appending to a list is a constant time operation. In each iteration we increment either `i` or `j`, so the total number of iterations is bounded by `n + m`.



<hr/>
<small>If you liked what you read, and want more like it, consider supporting me at [Patreon](https://www.patreon.com/mailund).</small>
<hr/>

