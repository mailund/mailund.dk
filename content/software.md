+++
title = "Software"
date = "2018-09-09"
menu = "main"
tags = ["software"]
+++

I have written various software over the years. You can get a list of most of it at [GitHub](https://github.com/mailund). Below is a list of software I have worked on recently (and I promise to still be maintaining). I will do my best to handle issues with older software, but some of it is simply too old for me to keep track of.

## premarkdown

The [premarkdown](https://github.com/mailund/premarkdown) project is a preprocessor for my Markdown manuscripts. It contains code for analysing and processing Markdown files and producing one or more documents from them.

There is a command-line tool, `premd`, that does the processing. I call it "premed" for reasons that are lost to me, but it is my software and I can call it what I want. I can't pronounce "md" without adding a vowel, so…

This tool flattens a document where different Markdown files include other files. You can add plugins to collect information about the document while it is processed.

As it is right now, it is not a lot of preprocessing you can do. I plan to allow plugins to output text that will be included in the output at some point, but I first have to figure out how to do this.

## pmatch

The [pmatch](https://mailund.github.io/pmatch/) R package implements pattern-matching, similar to Haskell and SML.

You can define data types, for example a binary tree:

```r
tree := L(elm : numeric) | T(left : tree, right : tree)
```

and then match data against it, like

```r
f <- function(x) {
    cases(x, 
          L(v) -> v, 
          T(left,right) -> c(f(left), f(right)))
}
x <- T(T(L(1),L(2)), T(T(L(3),L(4)),L(5)))
f(x)
#> [1] 1 2 3 4 5
```

## foolbox

The [foolbox R package](https://mailund.github.io/foolbox/) is a toolbox for doing metaprogramming on R functions. It provides handles for rewriting functions using various callbacks.

For example, you can replace the function call f(y) in the body of g with the function body, 2 * x like this:

```r
f <- function(x) 2 * x
g <- function(y) f(y)

callbacks <- rewrite_callbacks() %>% 
    add_call_callback(f, function(expr, ...) quote(2 * x))

g %>% rewrite() %>% rewrite_with(callbacks)
#> function (y) 
#> 2 * x
```

Check the homepage for examples such as [partial evaluation](https://mailund.github.io/foolbox/articles/partial-evaluation.html). (The partial evaluation there is not particularly efficient; slower than just calling functions, actually. Maybe some day I can make it faster.)

## tailr

The [tailr R package](https://mailund.github.io/tailr/) implements the tail-recursion optimisation in R. You don't really get much of a speedup if you combine `pmatch` and `tailr`—hand-written looping functions will always be faster—but you avoid errors when running out of stack space.

If I could speedup the pattern matching in `pmatch`, I believe I could make this optimisation faster; using it would be easier than hand-written looping functions, so that might make the `tailr` package more interesting.

## gwf

The [gwf](https://gwf.readthedocs.io/en/latest/tutorial.html) program is something I wrote for handling workflows on our cluster. You can specify dependencies and such using a DSL in Python, and when you submit jobs to the cluster they will be scheduled with respect to these dependencies.

```python
from gwf import Workflow

gwf = Workflow()

gwf.target('TargetA', inputs=[], outputs=['x.txt']) << """
echo "this is x" > x.txt
"""

gwf.target('TargetB', inputs=[], outputs=['y.txt']) << """
echo "this is y" > y.txt
"""

gwf.target('TargetC', inputs=['x.txt', 'y.txt'], outputs=['z.txt']) << """
cat x.txt y.txt > z.txt
"""
```

You can also get the status of them and such.

I am no longer the main developer of `gwf`. Dan Søndergaard has taken over, and I do not contribute much to the tool any more. Mostly because I am not running a lot of jobs on clusters. I might return to it later, when I need a cluster again.
