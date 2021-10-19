---
title: "Macro Metaprogramming"
date: 2021-10-18T04:43:09+02:00
categories: [Programming]
tags: [programming, C]
---

I've been working on a small C library for Python- or Go-like slices the last couple of weeks. Essentially arrays, but where I can index from the end using negative numbers (like in Python) and where I can extract a sub-slice, `x[i:j]`, in constant time (like in Go; I implement them the same way as Go does).

There is nothing complicated in implementing such slices. You need a pointer to an underlying buffer and a length (and maybe a capacity), and that's that. The only thing that makes it difficult is that I need slices of different types. They all behave exactly the same, even with the same code, except for the type of the underlying buffer. That varies, and thus so does the return type of indexing, some initialisation code (where the user provides the buffer that must be of the correct type) and a few other things.

Nothing in the source code really changes, just the type information. But that is bad enough. C doesn't do generic types, and there are a couple of places where you need to provide type information. Composite expressions, for example. So, I figured macros would get me most of the way, with `_Generic()` expressions for static type dispatch. And it did; I have a solution I am reasonably satisfied with. Except that there is some redundancy in what code I must generate from macros to make it work.

I wasted a lot of time not quite getting there—the final realisation that I wouldn't make it was that I needed to generate macros, and you cannot do that in other macros. I gave up (but I will tell you about the solution I ended up with some other time; it isn't bad, just not quite what I wanted). Before I gave up, however, I went deep down the rabbit hole of macro meta-programming, and it is now my intent to drag you down with me.

Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn!

# Basic macro expansion

You haven't used C for long before you learn how to define and use macros. You use `#define` to, well, define a macro, 

```c
#define foo 42
```

and then you can use the token `foo` anywhere in your code, and it will be expanded to 42 before the compiler sees it.

```c
f(foo);
```

becomes

```c
f(42);
```

after the preprocessor has swept through the code.

You have two kinds of macros, the simple ones like `foo` above, called object-like, and then so-called function-like macros. The latter, you define with parentheses after the name and with zero or more arguments between the parentheses.

For example, we can define

```c
#define foo() 42
```

to get a function-like macro that doesn't take any arguments but expands to 42. For function-like macros, you have to provide the parentheses to expand the macro. The macro name alone, `foo`, isn't expanded.

```c
#define foo() 42
foo // not expanded
foo() // expanded
```

If you provide parameters to a function-like macro, you can use them inside the expansion:

```c
#define bar(x, y) x(y)
bar(foo, 42) // expands to foo(42)
```

Macro expansion is purely textual. The preprocessor doesn't understand the C language, so it would never guess that in

```c
#define expr(x) x
expr((struct foo){ .bar = a, .baz = b })
```

you are trying to give `expr()` a composite expression. It sees two arguments because there is a comma in the arguments you give `expr`, so you are calling `expr()` with `(struct foo){ .bar = a` and `.baz = b}`, and not a single token.

The preprocessor is rather dumb. It does text substitution, nothing more. It is annoying at times, but this can also allow you to manipulate parts of expressions if you so desire, so there is some sense to it.

That is something you will know after spending an afternoon learning C, but there is a bit more to macros and the rules for how they expand, and while pure text substitution isn't much of a programming language, you *can* do some meta-programming. Especially if you get to use variadic macros in ways that they were never intended to be used.^[We didn't have variadic macros when I learned C, but they've been in the standard since C99, so you should have them now.]

When hacking away on macro meta-programming, I learned a lot of tricks from these two blog posts:

- [C preprocessor magic](http://jhnet.co.uk/articles/cpp_magic)
- [C Preprocessor tricks, tips, and idioms](https://github.com/pfultz2/Cloak/wiki/C-Preprocessor-tricks,-tips,-and-idioms)

You might as well, but I will give my own twist on it below.

But we are getting ahead of ourselves. We need to dig a little further into how function-like macros are expanded before we move on.

# Macro expansion

When you expand a function-like macro,

```C
#define FOO(a, b, c) /* macro body */
FOO(foo(), bar(x, y), baz)
```

you have some intuition about what you expect to happen, but that intuition is probably from programming in C (or similar languages). You want `a` to get the value of evaluating `foo()` and then be used with that value in the body of `FOO`. Likewise for `b <- bar(x, y)` and `c <- baz`. And mostly, that is what happens. But this isn't C, and macros do not behave the same way. The rules for expanding a function-like macro, and the order in which they are applied, are:

1. Stringification.
2. Parameters substituted with replacement list (without performing expansion).
3. Concatenation.
4. Parameter tokens are expanded.
5. Rescan and expand the result

For object-like macros, jump to step 5.

## Stringification

If you put a single `#` in front of a macro parameter, that parameter is turned into a string. The string contains the verbatim argument you provided.

```c
#define foo(x, y) #x #y
foo(bar(42), baz(x, z)) // "bar(42)" "baz(x, z)"
```

There is no substitution and no further expansion, you get the argument as a string, and that's that. This is the first thing that happens, so such stringified arguments are not processed further.

We won't need stringification in the hacking below, so we won't need this rule for what follows, except that it can be a helpful trick to work out what macro calls expand to.

If you want to know what `f(x)` evaluates to in

```c
#define bar(x) 2 * x
#define foo(f, x) f(x)
foo(bar, 42)
```

you can use a macro that stringify its input and then get the result verbatim:

```c
#define s(x) #x
#define bar(x) 2 * x
#define foo(f, x) s(f(x))
foo(bar, 42)
```

Wrapping `f(x)` in `s(f(x))` will turn the substituted value for `f(x)` into a string (it will be `"bar(42)"`) and you can inspect it.

(Without the `s(-)` wrapper, you get `bar(42)`, which will be expanded to `2 * 42`. If you were hoping that the preprocessor would give you 84, you forgot that it only does text substitution; it will not evaluate expressions).

## Parameters substituted with replacement list 

This bit is simple enough. With

```c
#define foo(f, x) f(x)
foo(bar, 42)
```

that step translates `f(x)` into `bar(42)`, substituting `f` for the argument `bar` and `x` for the argument `42`. It just puts in the raw arguments again, just as for stringification. At this point, we don't expand the arguments.

Not that you can tell, because unless you do step 3, concatenation, they will be expanded in step 4 before you see any results.

But you can see the difference between not-substituting and substitution+evaluation with stringification:

```c
#define s(x) #x
#define bar(x) 2 * x
#define baz() bar
#define foo(f, x) #f s(f) #x s(x)
foo(baz(), 42)
```

Here, when you evaluate `foo(baz(), 42)` you can see that the argument for `f` is `baz()` (because we stringify first, but it will be substituted into `f` and evaluated in `s(f)` (substituted `s(f)` to `s(baz())` and then evaluated to `s(bar)`).

The two-step substitution plus evaluation is something you only notice if you concatenate…

## Concatenation

If you place two `##` between two tokens, you concatenate them. The tokens are just text, as always, so this means that `A ## B` becomes `AB` (unless we have substituted something in for `A` or `B`).

Consider these macros:

```c
#define foo(f, x) foo ## f(x)
#define qux(x) bar
foo(qux, 42)
```

When we call `foo(qux, 42)`, we might expect this to become `foo ## qux(42)` where `qux(42)` evaluates to `bar`, so the result should be `foobar`. But the rule is that we first substitute

```c
foo(qux, 42) => foo ## qux(42)
```

then we concatenate

```c
foo ## qux(42) => fooqux(42)
```

and assuming we do not have a `fooqux` macro, that is the end result. Concatenation binds tighter than evaluation, just like stringification binds tighter than substitution and concatenation.

You might think that one level of indirection will change this. After all, with

```c
#define s(x) #x
```

we delayed stringification one step.

So maybe we could do:

```c
#define cat(x, y) x ## y
#define foo2(f, x) cat(foo, f(x))
foo2(qux, 42)
```

The "might think" was a hint that this doesn't work, and it doesn't. And for the same reason that

```c
#define s(x) #x
#define bar(f,x) s(f(x))
bar(qux, 42)
```

gives us `"qux(42)"` and not `"bar"`. We don't expand the expression quite enough.

## Parameter tokens are expanded

After we have stringified, substituted and concatenated, we expand parameter tokens. That just means that we expand the parameters we got if they are macros.

Take the concatenation example:

```c
#define cat(x, y) x ## y
#define foo2(f, x) cat(foo, f(x))
foo2(qux, 42)
```

We expand `foo2(qux, 42)` by substituting the arguments to get `cat(foo, [f=qux]([x=42]))` where I have put the substitution in square brackets. In this step, we need to expand the macros in those substituted expressions, but `qux` evaluates to `qux`. It is a function-like macro, so `qux()` evaluates to something (it evaluates to `bar`), but `qux` without parentheses doesn't. And 42, of course, evaluates to 42. The result is `cat(foo, qux(42))` so the arguments to cat, which it will concatenate without evaluation, are `foo` and `qux(42)`. We do not evaluate `qux(42)` because that expression wasn't part of a parameter; we created it from two separate arguments.

Likewise, for 

```c
#define s(x) #x
#define bar(f,x) s(f(x))
bar(qux, 42)
```

we expand `bar(qux, 42) => s([f=qux]([x=42])) => s(qux(42))` and `s()` makes the argument into a verbatim string without expanding it.

Macros in arguments are expanded in this step; it is not that this step isn't doing anything. It is just that in these two examples, the expansion is to the verbatim input, `qux` to `qux` (and not `qux()` and `42` to `42`).

If the argument was something we could evaluate, then there would be an expansion at this step.

Consider this:

```c
#define qax() qux
bar(qax(), 42)
```

Here, the substitution gives us `bar(qax(), 42) => s([f=qax()]([x=42]))` and `[f=qax()]` is evaluated, `qax() => qux`, so the result is `s(qux(42)) => "qux(42)"`.

But if we do not evaluate something like `qux(42)`, then why do we evaluate `s(qux(42))` to get `"qux(42)"`?

That's the last step of the expansion.

## Rescan and expand the result

Once the stringification, substitution, concatenation and parameter-expansion is done, the preprocessor goes through the result once more, expanding the macros it finds.

If we take `bar(qux, 42)` up to this step, we have substituted to get `s(qux(42))`. The same with `bar(qax(), 42)` because `qax()` will have been evaluated, expanding to `qux`. So `s(qux(42))` is the expression the preprocessor has before the last step, and the last step is just going through this expression and substituting all the macros it finds. It goes left-to-right, so if `.` is the current position, it will go

```
	. s(qux(42))
```

see that there is a function-like macro, `s()`, evaluate it (following the same rules as we are following now, and replace the call with the result

```
	. s(qux(42)) => "qux(42)" .
```

We don't evaluate `qux(42)` because `s()` doesn't evaluate its input, it stringify it, and once we are past expanding `s`, we don't attempt to evaluate the result.

It is the same with

```c
#define cat(x, y) x ## y
#define foo2(f, x) cat(foo, f(x))
foo2(qux, 42)
```

After all the substitution brouhaha, `foo2(qux, 42)` was turned into `cat(foo, qux(42))`, so that is what we scan.

```
	. cat(foo, qux(42)) => fooqux(42) .
```

Since `cat` concatenates its input verbatim, we do not evaluate `qux(42)`.

Is there then no way to evaluate before concatenating? Of course, there is; we just need to cheat the preprocessor into doing it. If one level of indirection doesn't work, try two:

```c
#define cat(x, y) x ## y
#define cat2(x, y) cat(x, y)
#define foo3(f, x) cat2(foo, f(x))
foo3(qux, 42)
```

Here, `foo3(qux, 42)` is transformed into `cat2(foo, [f=qux]([x=42]))` and which gives us `cat2(foo, qux(42))`, and that is what we need to evaluate. It's a macro call, so same procedure as always.

We substitute to go from `cat2(foo, qux(42))` to `cat([x=foo],[y=qux(42)])` and notice that this time, when we evaluate the parameters, we have an expression to evaluate: `qux(42) => bar`! That means that after the substitution we get `cat(foo, bar)` and when we do the second scan we will evaluate `cat(foo, bar) => foobar`.

Anyone who says that C's preprocessor macros are easy to use probably hasn't used them that much… the rules are simple, perhaps, but they are tricky.

And there is more to them. Otherwise, we couldn't do half the meta-programming we can. But I think it is time for a little break to see how we can do something useful with what we've got so far.

# Macros and choices

While the preprocessor has if/else statements

```c
#if FOO
# define BAR "foo"
#else
# define BAR "baz"
#endif
```

you cannot use those in macro expressions. You cannot write

```c
type x = if(foo)(bar)(baz);
```

and assign `bar` to `x` if `foo` is true and `baz` otherwise. Maybe that is not something you want to do, and that's okay, but it is something that you *can* do, with a bit of hacking.

The first bit to the trick is to use one macro to select another…

## Tables with macros

There's a trick that I have used a lot, and most recently with the slices I mentioned at the beginning of this post. If you have to choose between different expansions based on a type or a value, you can define macros for each choice and write another macro that picks the appropriate one.

It is roughly what you can do with `_Generic()` for types, but that feature is somewhat limited. You can only expand values to values and not, for example, types.

In my slice code, I use `_Generic()` to dispatch on types, but sometimes I must dispatch on a slice type and sometimes on an underlying type. So I defined macros that map from a slice type to the underlying type like this:

```c
#define CSTR_SLICE_BASE_sslice char
#define CSTR_SLICE_BASE_islice int
#define CSTR_SLICE_BASE_uislice unsigned int
#define CSTR_SLICE_BASE(TYPE) CSTR_SLICE_BASE_##TYPE
```

For each slice type, there is a `CSTR_SLICE_BASE_`*<underlying>* macro, and the `CSTR_SLICE_BASE(TYPE)` picks the right one by concatenating `CSTR_SLICE_BASE_` with `TYPE`.

I use it to generate dispatch tables for the various generic macros I have:

```c
// This macro needs a dispatch map for each slice type
#define CSTR_DISPATCH_TABLE(FUNC, MTYPE)        \
    CSTR_DISPATCH_MAP(sslice, FUNC, MTYPE),     \
    CSTR_DISPATCH_MAP(islice, FUNC, MTYPE), \
    CSTR_DISPATCH_MAP(uislice, FUNC, MTYPE)

// Type-based static dispatch.
// ---------------------------
// Select a function based on the type of S and
// the dispatch table in, then call it with the
// remaining arguments.

// Maps a type to the corresponding function
#define CSTR_DISPATCH_MAP_(TYPE, FUNC) \
    cstr_##TYPE : cstr_##FUNC##_##TYPE
#define CSTR_DISPATCH_MAP_B(TYPE, FUNC) \
    CSTR_SLICE_BASE(TYPE) * : cstr_##FUNC##_##TYPE
#define CSTR_DISPATCH_MAP(TYPE, FUNC, MTYPE) \
    CSTR_DISPATCH_MAP_##MTYPE(TYPE, FUNC)

// Dispatch a function based on the type of X
#define CSTR_SLICE_DISPATCH(X, B, FUNC, ...) \
    _Generic((X), CSTR_DISPATCH_TABLE(FUNC, B))(__VA_ARGS__)
```

It is a bit messy, but I will explain it some other time. The point is that I can, for example, write a generic macro that creates a slice from a buffer and a length, where I need the underlying base-type to dispatch on:

```c
#define CSTR_SLICE(BUF, LEN) \
    CSTR_SLICE_DISPATCH(BUF, B, new, BUF, LEN)
```

```c
// Dispatching on underlying type
cstr_sslice x = CSTR_SLICE(sbuf, 1024);
cstr_islice y = CSTR_SLICE(ybuf, 1024);
```

Or I can dispatch on a slice type to, for example, extract a sub-slice.

```c
// subslice: x => x[i:j]
#define CSTR_SUBSLICE(S, I, J) \
    CSTR_SLICE_DISPATCH(S, , subslice, S, I, J)
```

```c
cstr_sslice z = CSTR_SUBSLICE(x, 13, 42);
cstr_islice w = CSTR_SUBSLICE(y, 13, 42);
```

What is relevant here is that you can write a macro

```c
#define foo(x) foo_ ## x
```

that lets you pick other macros

```c
#define foo_bar qux
#define foo_baz qax
```

```c
foo(bar) // => foo_bar => qux
foo(baz) // => foo_baz => qax
```

## If-statements

Picking macros via concatenation also works for function-like macros. For example:

```c
#define if_else(b) if_##b
#define if_0(...) else_0
#define if_1(...) __VA_ARGS__ else_1
#define else_0(...) __VA_ARGS__
#define else_1(...)
```

Here, we define `if_else(b)`, where `b` must be 0 or 1, such that it either picks `if_0` (where `b` is 0) that will ignore its parameters but evaluate to `else_0`, or it evaluates to `if_1` that will expand its parameters and follow them with `else_1`. The idea is that you would call `if_else()` followed by an if-part in parentheses, thus invoking either `if_0` or `if_1`, and then they provide an else part that you invoke with a second set of arguments. It could look like this:

```c
if_else(0)(abort())(printf("yeah!\n"));
if_else(1)(printf("also yeah!\n"))(abort());
```

If `b` is 1, we get the arguments in the if-part and then an else part that throws the second set of parameters away. If we call with `b` equal to 0, we throw away the first part and provide an else part that will include the parameters there. Both if and else parts use variadic arguments, `…` and `__VA_ARGS__` to handle any set of arguments.

It is simple, and it works, but it is also pretty useless. You have to provide verbatim 0 or 1 to the `if_else` macro, or it doesn't pick `if_0` or `if_1`, it will simply expand to some `if_foo` token that likely isn't even defined. Unless we can evaluate `b` as some sort of test expression, we might as well just choose `if_0` or `if_1` direction.

## Testing expressions

It gets a little hairy now, but once you get the trick, it is pretty neat.

We can use variadic macros to pick true or false values. It goes like this:

```c
#define second(a, b, ...) b
#define test(p) second(p, 0)
#define is_true() -, 1
```

The `second()` macro gives you the second value in its input, and if `second(p, 0)` expands to something where `p` doesn't contain any commas, that will be zero. If, however, we call `test(is_true())`, then `p` expands to `-, 1`, so `second(p, 0)` becomes `second(-, 1, 0)` which evaluates to 1. In other words, `test(is_true())` is 1, and `test(xxx)` for any `xxx` that doesn't expand to something with a comma in it, will be 0.

We cannot guard against someone shoving some macro into `test()` that expands the way that `is_true()` does, but this is C, and nothing is ever safe. It is good enough.

```c
test(x) // 0
test(is_true()) // 1
```

So, anyway, we can write macros that either expand to `is_true()` or not, and if they expand to `is_true()` we can use that to get a truth-value out of them.

We can use it to define a not operator, `x => !x`:

```c
// 0 => 1, everything else is 0
#define cat(a,b) a##b
#define not(b) test(cat(not_,b))
#define not_0 is_true()
```

We use `cat(not_,b)` to expand `b` into 0/something and then call `test` with the result of the expansion. If `cat(not_,b)` is `not_0` that will expand to `not_0 => is_true()` so the call to `test(p)` gives us 1. If `b` is not 0, then `cat(not_,b)` becomes some single token, `not_xxx`, which becomes the first token in `second(p, 0)` and we get 0.

So, we can test for 0 now, and from that we can test for non-zero using the familiar `!!x` operation to translate any `x` into its truthiness boolean.

```c
// 0 => 0, everything else 1
#define truthiness(b) not(not(b))

truthiness(foo) // => 1
truthiness(0)   // => 0
truthiness(1)   // => 1
```

We can use `truthiness()` in our `if_else` to handle more general input. Zero will still mean false, but everything else will be true.

This will not work:

```c
#define if_else(b) cat(if_,truthiness(b))
```

because evaluating `if_else(xxx)` will substitute to `cat(if_,truthiness([b=xxx])) => cat(if_,truthiness([xxx]))` and the `xxx` is the end of the parameter evaluation. That means that on the scan of the expression after substitution we see `cat(if_,truthiness(xxx))` which we call `cat()` with, and it will translate it into `if_truthiness(xxx)` which isn't what we want. We need to make sure that the `truthiness(b)` expression is evaluated before we invoke `cat`, and we can do that by one level of indirection:

```c
#define if_else(b) if_else_(truthiness(b))
#define if_else_(b) cat(if_,b)
```

Now `if_else(xxx)` gets expanded to `if_else_(truthiness([b=xxx])) = if_else_(truthiness(xxx))` and inside `if_else_` we get `cat(if_,[b=truthiness(xxx)])` where `truthiness(xxx)` is evaluated before we call `cat`.

You can also use a similar trick to check if a macro received any arguments:

```c
#define first(a, ...) a
#define is_nil(...) test(first(is_true __VA_ARGS__)())
```

The trick to this is that `first(is_true __VA_ARGS__)` will be `first(is_true) = is_true` if `__VA_ARGS__` is empty, but if `__VA_ARGS__ = x, y, z` then `first(is_true __VA_ARGS__) = first(is_true x, y, z) is_true x` (notice no comma between `is_true` and `x`). So

```c
	first(is_true __VA_ARGS__)() [substitute] =>
	first(is_true)() [eval first() in scan] =>
	is_true()
```

which will be true when we give it to `test()`, while

```c
  first(is_true __VA_ARGS__)() [substitute] =>
  first(is_true x, y, z)() [eval first()] =>
  is_true x()
```

which, as long as `x()` doesn't expand to something with a comma when we give it to `test()`, will be false.

# Macros and recursion

So we have the power to create if-statements, but can we also iterate over arguments? We could use variadic parameters as a kind of list

```c
#define head(a, ...) a
#define tail(a, ...) __VA_ARGS__
#define is_nil(...) test(first(is_true __VA_ARGS__)())
```

so could we write a `map()` function?

```c
#define map(f, ...)                    \
    if_else(is_nil(__VA_ARGS__)).      \
    () /* do nothing, we are done */   \
    (  /* apply to head and recurse */ \
      f(head(__VA_ARGS__))             \
      map(f, tail(__VA_ARGS__))        \
    )

#define foo(x) f(x)
int x[] = { map(foo, x, y, z) };
```

It looks so right, and yet,

```c
int x[] = { map(foo, x, y, z) };
```

only expands to

```c
int x[] = { f(x) map(foo, y, z) };
```

It looks like the recursive call simply isn't expanded.

## The preprocessor really doesn't like recursion

The preprocessor doesn't immediately allow recursion. It actually works hard to disable it. This is to avoid issues such as `foo` and `bar`, here, that if you tried to expand them would give you an infinite expansion.

```c
#define foo F bar
#define bar B foo
```

The way it works is, the preprocessor knows which macros it is in the process of expanding, and if it sees any of those during the expansion, the expansion there is tagged (painted blue, in the parlance), and that expansion is forever left as is.

Say you want to expand `foo` above. Then you enter a state that knows that it is expanding `foo`, it handles the token `F` without any issues (it is not a macro, so it is left as it is)

```c
foo // foo => [foo] F . bar
```

but when it needs to expand `bar` it expands the tokens there and remembers that it is now expanding both `foo` and `bar`. Then it scans alone, past `B` that doesn't require any special handling, and it runs into `foo`. Since it is in the process of expanding a `foo`, this `foo` cannot be expanded. It is tagged, and in any future processing, it will be left alone.

```c
//     => [foo, bar] F B . foo<tagged>
//     => F B foo<tagged>
```

Expanding `bar` is similar: you are in a context where you are expanding `bar`, you can easily handle `B`, but you need to expand `foo`. Inside `foo`, you can handle `F`, but when you see `bar`, you must tag it, and it cannot be expanded any further.

```c
bar
// bar => [bar] B . foo
//     => [bar, foo] B F . bar<tagged>
//     => B F bar<tagged>
```

We can define `foobar` as first a `foo` and then a `bar`, and see that it is the recursive expansions that disable some expansions, not consecutive ones.

```c
#define foobar foo bar
```

If we expand `foobar`, we first have to expand `foo`, so now we will be in a context where we are expanding `foobar` and `foo`. Inside `foo`, things progress as above, we leave `F` alone, we expand `bar`, then get a `B` and then a tagged `foo` because we cannot expand recursively.

```c
foobar
// foobar => [foobar] . foo bar
//        => [foobar,foo] F . bar bar
//        => [foobar,foo,bar] F B . foo<tagged> bar
```

After handling `foo`, we have another `bar` to handle. While we expanded `foo`, we were in a `bar` context where expansions of `bar` were disabled, but we are no longer in that context, and we can expand `bar` again, which we do.

```c
//        => [foobar] F B foo<tagged> . bar
//        => [foobar,bar] F B foo<tagged> B . foo
```

In the expansion of `bar`, we see `foo`, which is no longer disabled, so we can expand that, and the whole `bar` processing progresses as earlier.

```c
//        => [foobar,bar,foo] F B foo<tagged> B F . bar<tagged>
//        => F B foo<tagged> B F bar<tagged>
```

Expansion works as you would expect, with the same rules we have discussed earlier if we are working with function-like macros, except that recursion isn't allowed.

What's with the tagging, though? Why is that done? Couldn't we just leave the expansion alone?

I suppose we could, but they must have a reason for tagging macros that way, and it does make a difference.

Let's say we define this `foo` macro:

```c
#define foo(x) [x] foo
```

If we call it as 

```c
foo(42)(32)
```

it expands to

```c
[42] foo(32)
```

and we should be able to evaluate this expression again to get

```c
[42] [32] foo
```

for example with:

```c
#define eval(...) __VA_ARGS__
eval(foo(42)(32))
```

We won't get `[42] [32] foo`, though; `eval()` leaves `foo(32)` alone in the expansion. Because we saw that `foo` inside the expansion of `foo`, it is tagged. It doesn't matter that we didn't see it as a function-like macro; that just prevented us from expanding it; we saw it, and it is now impossible to expand.

It doesn't have to be this way. We can trick the preprocessor to expand to someing that that doesn't contain a forbidden name, and then we can evaluate at a later time.

For example, 

```c
#define bar(x) <x> bar_
#define bar_(x) bar(x)
```

Here, `bar(42)` will expand to `<42> bar_`, not seing any recursive expansion and so it will not tag anything. That means that we can evaluate

```c
bar(42)(32)
```

to get

```c
<42> bar_(32) => <42> bar(32) => <42> <32> bar_
```

It looks promising, but we are not out of the woods. The last expansion, which gave us the third `bar_`, happened inside an expansion of `bar_`, so it is tagged, and we won't expand further.

```c
bar(42)(32)         // => <42> <32> bar_
bar(42)(32)(22)     // => <42> <32> bar_(22)
bar(42)(32)(22)(11) // => <42> <32> bar_(22)(11)
```

The preprocessor figured out that we were trying to cheat it.

Still, the idea is sound. If we can avoid expanding to a forbidden token while we evaluate a macro, we should be able to get an expression back that we can evaluate to get the next step of a recursion.

We just got `bar_` expanded too early, while we were still expanding a `bar_`.

We can delay an evaluation by putting something between the name of a function-like macro and the parentheses that causes its expansion.

```c
#define empty()
#define delay(f) f empty()
```

If you evaluate `delay(foo)` you expand to `foo empty()`, since there are no parentheses after `foo` it isn't expanded, but `empty()` is expanded, and to the empty string, so the result is an unevaluated `foo`. If you write `delay(foo)()`, then it evaluates to `foo()`, a macro call waiting to happen. As long as `foo` isn't forbidden itself, it can expand to something that is at a later point, and in that way circumvent the recursion protection.

Try defining

```c
#define foo_() foo
#define foo(x) [x] delay(foo_)() (x)
```

Then

```c
foo(42)
```

expands to 

```c
[42] foo_ () (42)
```

where `foo_` isn't tagged and can be evaluated, so

```c
eval(foo(42))
```

expands

```c
eval(foo(42)) 
  => […=[42] foo_() (42)]
  => [42] foo(42)
  => [42] [42] foo_() (42)
```

ready for another expansion.

Let's try to put that into the recursive `map()` macro:

```c
#define map_() map
#define map(f, ...) \
    if_else(is_nil(__VA_ARGS__))\
    ()\
    (f(head(__VA_ARGS__)) \
     delay(map_)()(f, tail(__VA_ARGS__)))
```

It doesn't work. We still only get the first item handled.

```c
map(foo, x, y, z)             // f(x) map(foo, y, z)
eval(map(foo, x, y, z))       // f(x) map(foo, y, z)
eval(eval(map(foo, x, y, z))) // f(x) map(foo, y, z)
```

What gives?

The problem is, once again, that we reveal our intentions to do recursion a bit too early. The `delay()` macro prevents expansion for one attempt, but we have two here. One for the `map()` macro and another for the `else_0` function that handles the recursive case. If we want to implement recursion this way, we need to prevent two attempts at expansion.

This is, fortunately, quite easy to fix. If we write `empty empty() ()`, then the first expansion will remove the middle `empty()` leaving `empty()` for the next expansion.

```c
#define delay2(f) f empty empty()()

#define map(f, ...) \
    if_else(is_nil(__VA_ARGS__))\
    ()\
    (f(head(__VA_ARGS__)) \
     delay2(map_)()(f, tail(__VA_ARGS__)))

map(foo, x, y, z) // => f(x) map_ ()(foo, y, z)
eval(map(foo, x, y, z)) // => f(x) f(y) map_ ()(foo, z)
eval(eval(map(foo, x, y, z))) // => f(x) f(y) f(z) map_ ()(foo, )
eval(eval(eval(map(foo, x, y, z)))) // => f(x) f(y) f(z)
```

It is not much fun, of course, if we have to explicitly evaluate for each expansion of the recursion, but we we can build exponentially larger number of expansions like this:

```c
#define expand_1(...) __VA_ARGS__
#define expand_2(...) expand_1(expand_1(__VA_ARGS__))
#define expand_4(...) expand_2(expand_2(__VA_ARGS__))
#define expand_8(...) expand_4(expand_4(__VA_ARGS__))
#define expand_16(...) expand_8(expand_8(__VA_ARGS__))
```

and pick one level, high enough, for our evaluation function. (16 probably isn't, but it is good enough here).

```c
#define eval expand_16
```

Then we can add `eval()` to the macro, at the outermost layer, to get this map function:

```c
#define map(f, ...) \
    eval(map_(f, __VA_ARGS__))
#define map__() map_
#define map_(f, ...) \
    if_else(is_nil(__VA_ARGS__))\
    ()\
    (f(head(__VA_ARGS__)) \
     delay2(map__)()(f, tail(__VA_ARGS__)))
```

and presto:

```c
#define foo(x) f(x), 
int x[] = { map(foo, x, y, z) };
```

gives us

```c
int x[] = { f(x), f(y), f(z), };
```

I find it a bit scary that you can program this way with C's preprocessor. It is pretty cool, but I am happy that I ended up not using too crazy things for my slices. It was bad enough where that code landed.

