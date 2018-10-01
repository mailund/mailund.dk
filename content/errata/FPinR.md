+++
title = "Errata: Functional Programming in R"
date = "2018-10-01"
tags = ["books", "writing", "functional-programming", "rstats", "errata"]
+++

## Chapter 2

### The Structure of a Recursive Function, page 32:
"Here I am assuming that is an integer…" should be "Here I am assuming that n is an integer…"

## Chapter 3

### Nested Functions and Scopes, page 53ff.

The code defines function g as `g <- function(y) x + y` but in the environment chains g is defined as `g <- function(y) x + 1`; that should also be `g <- function(y) x + y`.

