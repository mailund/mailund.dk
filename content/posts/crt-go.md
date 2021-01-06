---
title: "Chinese Remainder in Go"
date: 2021-01-06T10:56:53+01:00
tags: [Go, Programming]
categories: [go, programming]
---

In between exams, I plan to learn [Go](https://golang.org) in January. I have a book I plan to follow, but today I wanted to get started by just jumping into it, so I picked the [Chinese Remainder Theorem](https://en.wikipedia.org/wiki/Chinese_remainder_theorem) we used for 2020's Advent of Code [Day 13](https://mailund.dk/posts/aoc-2020-4/). There, I implemented it in Python (before I found out that it was already in SymPy). It is a simple numerical algorithm, so it should be easy to implement in Go. Or so I thought.

I only implemented the algorithm for two equations. Given numbers \\(a,n,b,m\\) with \\(a < n\\) and \\(b < m\\), find \\(x\\) such that \\(x\\) mod \\(n = a\\) and \\(x\\) mod \\(m = b\\). If you can do that, you can iteratively solve for any number of equations. To do that, however, I need to work out how to handle arrays in Go, and I didn't take it that far. I will do that later.

One way to solve the equations is to find the Bézout coefficients \\(s\\) and \\(t\\). Those are numbers such that \\(sn+tm=1\\), and if you have them, then your solution is \\(x = atm + bsn\\). To see this, note that because \\(s\\) and \\(t\\) are Bézout coefficients, \\(sn = 1 - tm\\) and \\(tm = 1 - sn\\), so \\(x\\) mod \\(n\\) = \\((atm+bsn)\\) mod \\(n = atm\\) mod \\(n\\) (because \\(bsn\\) is divisible by \\(n\\)) and \\(atm\\) mod \\(n\\) = \\(a(1-sn)\\) mod \\(n\\) = \\(a\\) mod \\(n\\) and symmetrically for \\(b\\) and \\(m\\). So, to find \\(x\\), you need to find \\(s\\) and \\(t\\). It isn't the only way, I think, but it is an easy way, because the [extended Euclidian algorithm](https://en.wikipedia.org/wiki/Extended_Euclidean_algorithm) will do it for you.

The extended Euclidian algorithm works the same way as the Euclidian algorithm for computing the greatest common divisor of two numbers, you just keep track of two additional numbers in the computation. In Go, it looks like this:

```go
func egcd(a, b int64) (int64, int64, int64) {
	oldR, r := a, b
	oldS, s := int64(1), int64(0)
	oldT, t := int64(0), int64(1)
	for r != 0 {
		quotient := oldR / r
		oldR, r = r, oldR-quotient*r
		oldS, s = s, oldS-quotient*s
		oldT, t = t, oldT-quotient*t
	}
	return oldR, oldS, oldT
}
```

My implementation returns three numbers. The first is the GCD of `a` and `b`—which for the Chinese Remainder Theorem is one as the input must be co-primes—and the second and third are \\(s\\) and \\(t\\).

That is the easy part, because now we can get the solution with

```go
func crt(a, n, b, m int64) (int64, int64) {
	K := n * m
	_, s, t := egcd(n, m)
	x := a*t*m + b*s*n
	if x < 0 {
		x += K
	}
	return x, K
}
```

Here, \\(K\\), is the product of \\(n\\) and \\(m\\) and \\(x\\) should be modulo that. It might be negative, and if it is, we move it one period of \\(K\\) up to get the corresponding equivalence class. Adjusting a number this way, when you work modulo some number is standard. Nothing exciting here.

In my Python implementation, that would be it. Python works with arbitrarily large integers, and while that can hurt performance when numbers grow large, it isn't an issue here. The benefit of using such numbers is that we do not get overflow. But with Go (and most languages), we have a fixed size for integers. I picked 64-bit numbers, because that often suffices, but not for me. In some of my test cases, the multiplications when creating \\(x\\) gave me overflow.

So I figured that I would do multiplication in 128-bit words and then take the remainder with \\(K\\). That way, I would avoid overflow in the individual multiplications, and if I take the remainder after each operation, I would stay in 64-bit integers. However, Go told me in friendly but no uncertain terms that `int128` was not a type. And that meant that I had to do the multiplication within the modulo group.

You can do that with iterative addition, but it is of course very slow. It is linear in the smallest of the factors. But I figured that I should definitely be able to multiply by two without overflow, or I might as well give up, so I implemented a logarithmic multiplication.^[Well, it depends on how you look at the data. I suppose it is pseudo-logarithmic, because it is logarithmic in the magnitude of the input and not the size of the input. It doesn't really matter what you call it; it is fast enough.] I don't know what it is called, but it is a standard algorithm. You multiply by two when you have an even number, and add when you have an odd.

```go
func multmod(a, b, m int64) int64 {
	var result int64 = 0
	a %= m
	b %= m

	for b != 0 {
		if b%2 != 0 {
			result = (result + a) % m
		}

		a = (a * 2) % m
		b /= 2
	}

	return result
}
```

I also wrote a function to handle moving a number from negative into the range \\([0,\ldots,K-1]\\):

```go
func mod(a, m int64) int64 {
	a %= m
	if a < 0 {
		a += m
	}
	return a
}
```

With those functions, a Chinese Remainder solution looks like this:

```go
func crt(a, n, b, m int64) (int64, int64) {
	K := n * m
	_, s, t := egcd(n, m)
	atm := multmod(multmod(a, mod(t, K), K), m, K)
	bsn := multmod(multmod(b, mod(s, K), K), n, K)
	x := mod(atm+bsn, K)
	return x, K
}
```

Somehow, I miss operator overloading right here, but I don't think Go has them. I should get started with my book so I can figure out what you can actually do in Go.
