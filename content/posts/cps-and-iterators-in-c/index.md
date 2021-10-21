---
title: "CPS and Iterators in C"
date: 2021-10-21T04:50:01+02:00
categories: [Programming]
tags: [programming, C]
---

Today, I want to talk about *continuation-passing-style* (CSP). This is a general approach you can use to translate recursions into tail-calls.

What's tail-calls, I (imagine hearing) you ask?

A [tail-call](https://en.wikipedia.org/wiki/Tail_call) is when a function calls another function as the last thing it does. Tail-recursion is when that last call is a recursive call, but that is just a special case of tail-calls.

This is a recursive function, in Python, that computes the factorial of a number:

```python
def fact(n):
    match n:
        case 0: return 1
        case _: return n * fact(n - 1)
```

(I use pattern matching from Python 3.10, but you can probably easily implement it without matching yourself).

It isn't tail-recursive, because after calling recursively, `fact(n - 1)`, we take the result and multiply it with `n`. The multiplication is the last thing we do, not the recursive call.

To make a tail-recursive version, we can add an accumulator and get:

```python
def fact(n, acc = 1):
    match n:
        case 0: return acc
        case _: return fact(n - 1, n * acc)
```

Now, the last thing we do in the recursion is calling recursively, `fact(n - 1, n * acc)`. We've moved the multiplication into an argument, so we don't need to wait for the recursion to finish to do it.

The nice thing about tail-calls is that since the call is the last thing to do, you do not need to remember any state for when it finishes, so you don't need the call frame any more. The new call can take over the existing frame, and when it returns, it can return directly to the point of the original call rather than back to the calling function just to return immediately again. In other words, tail recursion can be translated into a loop in a straightforward manner.

```python
def fact(n, acc = 1):
    while n > 0:
        # update variables instead of calling recursively
        n, acc = n - 1, n * acc
    return acc
```

Translating recursion into a loop has several benefits. Looping is (slightly) faster than calling and returning from functions, but more importantly, reusing a stack frame reduces the stack space you need for a function, and stack space is a limited resource.

You don't notice this often, you usually don't recurse that deeply, but it can be a problem. If you use recursion to go down a balanced search tree, you won't have any problems unless the tree is gigantic, because a balanced tree has depth O(log n). If n is four billion, the depth is (if perfectly balanced) only 32, and that is never an issue.

But try traversing a suffix tree over a string of a few million characters. Those bastards can be highly un-balanced, and then you have a problem. You run out of stack space, and your program will not take that kindly.

Optimising tail-calls into loops get rid of the problem entirely. Calls become loops, and you only need a single stack frame for the entire thing.

Plus, the loop transformation is easy to do. It is so simple that you can automate it. [I did it (with some limitations) for R in a package.](https://github.com/mailund/tailr).

If it is simple enough that I can do it, then you can bet that compilers can do it. For pure functional languages, they are guaranteed to do it. There you don't have loops at all, you only have recursion, so it is imperative that those recursions can be translated into loops.

Python, not being a functional language, does not implement the tail-call optimisation, though. R, a functional language but one that has loops, doesn't do it either. Whether this is out of laziness or because they think that you should just use loops, I don't know. But you can make the transformation yourself, as I did for `fact(n)` above.

But what happens if you need to call more than one function? What if you need to recurse twice?

What can you do about something like the Fibonacci numbers?

```python
def fib(n):
    match n:
        case 0 | 1: return n
        case _: return fib(n-1) + fib(n-2)
```

(I know this is a stupid example, because the obvious iterative way of computing Fibonacci numbers will be asymptotically much faster and never need more than one stack frame, but it is a simple and well-known example, so go with it…)

At best, you can make one of the recursive calls the last call. It looks like you would have to make at least one recursive call that needs stack space.

At least if we think about recursion the usual way, where we do some work going down the recursion and some other work coming back. But we don't have to think this way. We can get rid of the usual call-return thinking and replace it with something else: continuations.

# Continuations and continuation-passing-style

Imagine that the `return` statement doesn't exist, and instead we always have to call a function to move the control-flow somewhere else. Functions take such a function as argument, we call it a *continuation*, and when they want to "return", i.e., pass back control-flow to something the caller intended, we call that function.

When we call a function, we can hook into that mechanism. If there is something we need to get done with the result of the function call, we can give the function a continuation that does it. It will be called with the result of the call, then it can do what extra work we need doing, and then invoke the continuation that takes us back to our caller.

```python
def fact(n, k = lambda x: x):
    match n:
        case 0:
            # base case: call continuation on base
            return k(1)
        case _: 
            # recursive all, give it a continuation
            # that multiplies the result of the
            # recursion to n
            return fact(n - 1, lambda res: k(n * res))
```

This is Python, we still have `return` and we need to use it to make a call to `fact(n)` return the normal way, but all the calls are tail-calls and we return the result of those calls. We just provide a continuation at each step that does what we would normally do with the return value. The recursion will go all the way down from `n` to `0` and along the way it will build up a string of continuations for multiplying the numbers.

Once we reach 0, we call the continuation, and that starts evaluating all the accumulated functions.

The computation works the same way as the direct recursion: first you go all the way down to zero, and then you multiply all the numbers. The multiplication is just not done in the original recursive functions but in the continuations.

Without the tail-call optimisation, this is a bad idea. Instead of just filling the stack with recursive calls, we first fill it with the recursions and *then* we double the number of stack frames by invoking the continuations. So, in Python or R, this is not a good idea.

You can get out of the problem using thunks and trampolines. I've written about those for R in [Functional Programming in R](https://amzn.to/3jnoeUj) and for Python in [Introduction to Computational Thinking](https://amzn.to/3C3euGj), so I won't write more about it here. In any case, this post is about C that *does* implement tail-call optimisation (and just not all the other things we need to make CPS work, but we can do that ourselves).

How does continuations allow for tail-calls with multiple recursions? Easy enough, you call the first recursion with a continuation that is responsible for the second (or third or fourth, …) recursion. It will be invoked when the first recursion is done, and now you have the stack frame free for use for another string of recursions and continuations.

Here's `fib(n)` with continuations:

```python
def fib(n, k = lambda x: x):
    match n:
        case 0 | 1: return k(n)
        case _:
            def k1(res1):
                return fib(n - 2, lambda res2: k(res1 + res2))
            return fib(n - 1, k1)
```

The continuation `k1` is the function we give to the first recursion. It will eventually be called with the result of `fib(n - 1)`. Then it needs to compute `fib(n - 2)` so it can add the results of the two recursion, so it will call `fib(n - 2)` with a new continuation. That continuation, `lambda res2: …` will get the result of `fib(n - 2)`, so now it has both `res1 = fib(n - 1)` and `res2 = fib(n - 2)` and it can add the two and give the result to the original continuation, `k(res1 + res2)`, thus passing the result on to the callers continuation.

If you take a general function and identify all the function calls it make, you can split the function at those places. Everything that comes after a function call, where you would normally continue the computation, you can put in another function and make a continuation.

[Call/cc](https://en.wikipedia.org/wiki/Call-with-current-continuation) does something to that effect, while still looking like a normal call-return, but we don't have that in C or Python (you do have it in R), so that isn't useful for us here; we would need to split functions in this way. And you always can, so you can always translate functions into tail-call versions.

Okay, I introduced the idea with Python, because Python has high-order functions and closures, and it is simple to implement CPS there. (Even though you won't get the benefits of it, as the tail-call optimisation isn't there).

I want to do it in C.

There is a reason why I'm interested in doing it in C, and I'll get back to that before the post is over, but for now, let's just check if it is something we can do.

# Tail-call optimisation in C

The C standard doesn't require that compilers implement tail-call optimisation, but they usually do if you turn on optimisation. I tested a few compilers with this C-version of the factorial function:

```c
int fact(int n, int acc)
{
    if (n <= 1) return acc;
    return fact(n - 1, acc * n);
}
```

Without optimisation, the compilers won't do any optimisation, including tail-calls, so I tested with `-O2` or the equivalent. I used [https://godbolt.org](https://godbolt.org); my go-to places for checking the code that compilers generate.

Here's the result `gcc 11.2 (x86_64)`:

```asm
fact:
        mov     eax, esi
        cmp     edi, 1
        jle     .L5
.L2:
        imul    eax, edi
        sub     edi, 1
        cmp     edi, 1
        jne     .L2
.L5:
        ret
```

It's rather straight-forward, but if you don't speak assembler, just know that a call in `x86_64` is done with the instruction `ret`, and here there isn't any. That means that the function does not call any other function. The `jne .L2` is a loop, and it is what the recursive call was translated into.

Here's the code generated by `msvc 19.10 (x86_64)`:

```asm
n$ = 8
acc$ = 16
fact    PROC                                            ; COMDAT
        cmp     ecx, 1
        jle     SHORT $LN11@fact
$LL4@fact:
        imul    edx, ecx
        dec     ecx
        cmp     ecx, 1
        jg      SHORT $LL4@fact
$LN11@fact:
        mov     eax, edx
        ret     0
fact    ENDP
```

Again, there is no `call` instruction, but there is the `jg SHORT $LL4@fact` instruction that is the corresponding loop.

With `icc 19.0.1 (x86_64)`:

```asm
fact:
        mov       ecx, edi                                      #13.1
        mov       eax, esi                                      #13.1
        cmp       ecx, 1                                        #14.14
        jle       ..B1.9        # Prob 12%                      #14.14
        cmp       ecx, 2                                        #14.14
        jle       ..B1.11       # Prob 12%                      #14.14
        lea       esi, DWORD PTR [-1+rcx]                       #15.21
        imul      esi, ecx                                      #15.30
        cmp       ecx, 3                                        #14.14
        jle       ..B1.10       # Prob 12%                      #14.14
        lea       edx, DWORD PTR [-2+rcx]                       #15.21
        cmp       ecx, 4                                        #14.14
        jle       ..B1.6        # Prob 12%                      #14.14
        imul      esi, edx                                      #15.12
        lea       edi, DWORD PTR [-4+rcx]                       #15.12
        add       ecx, -3                                       #15.12
        imul      ecx, eax                                      #15.12
        imul      esi, ecx                                      #15.12
        jmp       fact                                          #15.12
..B1.6:                         # Preds ..B1.4
        imul      eax, edx                                      #15.30
        imul      eax, esi                                      #15.30
..B1.9:                         # Preds ..B1.1 ..B1.6
        ret                                                     #15.12
..B1.10:                        # Preds ..B1.3
        imul      eax, esi                                      #15.30
        ret                                                     #15.30
..B1.11:                        # Preds ..B1.2
        imul      eax, ecx                                      #15.30
        ret                                                     #15.30
  
```

This is a long one, it looks like the generated code has unrolled part of the underlying loop, but it is a looping version. There are jumps, of varying form, but no `call`, so no recursion.

(I won't show `clang`; it generates a rather long list of `xmms` instructions that I don't fully understand, worse than the loop unrolling above, but there is no `call` in there either).

It looks like we can have a fair chance of translating tail-recursion into loops. It will depend on the compiler, of course, the standard doesn't ensure it, but it is a reasonable expectation.

That's with recursion, but what about tail-calls to other functions. That's something that is hard to translate to a loop in your own code, but something we should be able to translate into jumps in assembler.

Let's try this code (you can probably recognise the recursion, and it isn't something I want to call, but it is three functions calling each other):

```c
int collatz(int n);
int even(int n);
int odd(int n);

static inline
bool is_odd(int n) { return (n & 1);                       }
int even(int n)    { return collaz(n / 2);                 }
int odd(int n)     { return collaz(3*n + 1);               }
int collatz(int n) { return is_odd(n) ? odd(n) : even(n) ; }
```

All the function calls (except to is_odd() that we expect to be inlined) are tail-calls. The Elvis-operator, `a ? b : c` is just a branch, only one of the branches is executed, so those are tail-calls as well. But they are not directly recursive calls. So we cannot immediately translate the code into a loop, at least not without inlining functions.

Let's check the generated assembler. With `gcc 11.2` we get:

```asm
even:
        mov     eax, edi
        shr     eax, 31
        add     edi, eax
        xor     eax, eax
        sar     edi
        jmp     collaz
odd:
        lea     edi, [rdi+1+rdi*2]
        xor     eax, eax
        jmp     collaz
collatz:
        test    dil, 1
        je      .L5
        lea     edi, [rdi+1+rdi*2]
        xor     eax, eax
        jmp     collaz
.L5:
        mov     eax, edi
        shr     eax, 31
        add     edi, eax
        xor     eax, eax
        sar     edi
        jmp     collaz
```

There is no `is_odd` function; it's been inlined as expected. In the `even` and `odd` functions we have a `jmp collaz` instead of `call collaz`, which is what we hoped for. In `collaz` we don't have jumps to `even` or `odd`, which we might have expected, but that is because the functions have been inlined.

This is to be expected when the functions are in the same compilation unit, and they are when I use godbolt.org. If you comment out the `even()` an `odd()` functions, though, the compiler cannot inline them, and then I get

```asm
collatz:
        test    dil, 1
        je      .L2
        jmp     odd
.L2:
        jmp     even
```

with `jmp` instead of `call`.

With `clang 13.0.00` we get:

```asm
even:                                   # @even
        mov     eax, edi
        shr     eax, 31
        add     eax, edi
        sar     eax
        mov     edi, eax
        xor     eax, eax
        jmp     collaz                          # TAILCALL
odd:                                    # @odd
        lea     edi, [rdi + 2*rdi]
        add     edi, 1
        xor     eax, eax
        jmp     collaz                          # TAILCALL
collatz:                                # @collatz
        mov     eax, edi
        test    al, 1
        jne     .LBB2_1
        mov     edi, eax
        shr     edi, 31
        add     edi, eax
        sar     edi
        xor     eax, eax
        jmp     collaz                          # TAILCALL
.LBB2_1:
        lea     edi, [rax + 2*rax]
        add     edi, 1
        xor     eax, eax
        jmp     collaz                          # TAILCALL
        
```

The calls in `even()` and `odd()` are translated into `jmp` (and then compiler is friendly to tell us in a comment). Once again, `even()` and `odd()` are inlined in `collatz`, but if I remove `even()` and `odd()` from the compilation unit, so the compiler cannot inline them, `collatz` becomes:

```asm
collatz:                                # @collatz
        test    dil, 1
        jne     .LBB0_1
        jmp     even                            # TAILCALL
.LBB0_1:
        jmp     odd                             # TAILCALL
        
```

`msvc 19.10` generates code for the inlined `is_odd()` (but still inline the function), and otherwise it is the same pattern:

```asm
n$ = 8
is_odd  PROC                                                ; COMDAT
        and     ecx, 1
        movzx   eax, cl
        ret     0
is_odd  ENDP

n$ = 8
even    PROC                                            ; COMDAT
        mov     eax, ecx
        cdq
        sub     eax, edx
        sar     eax, 1
        mov     ecx, eax
        jmp     collaz
even    ENDP

n$ = 8
odd     PROC                                          ; COMDAT
        lea     ecx, DWORD PTR [rcx+rcx*2]
        inc     ecx
        jmp     collaz
odd     ENDP

n$ = 8
collatz PROC                                          ; COMDAT
        test    cl, 1
        je      SHORT $LN3@collatz
        lea     ecx, DWORD PTR [rcx+rcx*2]
        inc     ecx
        jmp     collaz
$LN3@collatz:
        mov     eax, ecx
        cdq
        sub     eax, edx
        sar     eax, 1
        mov     ecx, eax
        jmp     collaz
collatz ENDP
```

with

```asm
n$ = 8
collatz PROC                                          ; COMDAT
        test    cl, 1
        jne     odd
$LN3@collatz:
        jmp     even
collatz ENDP
```

if we prevent inlining in `collatz()`.

It looks like we will get tail-call optimisation even if we call other functions.

This is promising.

# Closures

So, we can get tail-call optimisation, but for continuations to work, we need to store state together with functions, we need closures.

When we generate continuations, we are essentially moving the data that would normally go on the stack into closures (that we can have on the heap), but it is not a free ride. We need to store that data, and when we invoke a continuation later, we need to provide it with it.

It isn't that different from transforming a recursion into a loop with an explicit stack (although it is a bit more flexible because closures do not need to be invoked in a stack-like fashion). We need to store data in "stack" frames, in one form or another, but now we also need to associate the data with a function so we can call the right function with the right data when we need to invoke a continuation.

Since there is no built-in closures in C, we have to implement them ourselves, but that isn't much a problem. We need to associate a function with some data, we can use function pointers for functions, and then combine function and at a in a struct:

```c
struct closure {
    /* ret type */ (*fn)(/* args */, struct closure *);
    /* stuff you need to remember */
};
```

If we want to call such a closure, pick the function from it and call it with arguments and the struct.

```c
    cl->fn(/*args*/, cl);
```

There are a million variations on this, if you want to separate the data from the function and only provide the encapsulated data and such, but this is simple, and it is good enough for the likes of you and me.

Here's an example where closures are functions from integers to integers. That means the result type should be an integer and the closure should take one integer argument and one closure argument.

```c
struct closure {
    int (*fn)(int, struct closure *);
    int a;
};
```

To implement something like

```python
def add_a(a):
    return lambda b: a + b
```

we need a function that returns a closer, binding the variable `a`, and a function we wrap in the closure that takes `b` and add it to `a`.

```c
/* create a closure that will add a to its argument */
struct closure *add_a(int a);
/* add b to the a stored in the closure */
int add_b(int b, struct closure *cl);
```

Then we should be able to use it as this:

```c
int main(void)
{
    // Createt a closure, binding a to 2
    struct closure *cl = add_a(2);
    // now call the closure to add 42 to 2
    printf("%d\n", cl->fn(42, cl));
    
    free(cl); // closure was allocated on the heap
    return 0;
}
```

Which indeed we can.

The functions `add_b` and `add_a` could look like this:

```c
int add_b(int b, struct closure *cl)
{
    return b + cl->a;
}

struct closure *add_a(int a)
{
    struct closure *cl = malloc(sizeof *cl);
    *cl = (struct closure){ .fn = add_b, .a = a };
    return cl;
}
```

Easy-peasy.

What about continuations, then?

Let's do CPS factorial in C. The Python version was

```python
def fact(n, k = lambda x: x):
    match n:
        case 0:
            return k(1)
        case _: 
            return fact(n - 1, lambda res: k(n * res))```
```

The closures need to know `n` and the continuation `k`:

```c
struct closure {
    int (*fn)(int, struct closure *);
    int n;
    struct closure *k; // continuation
};

struct closure *new_closure(
    int (*fn)(int, struct closure *),
    int n, struct closure *k)
{
    struct closure *cl = malloc(sizeof *cl);
    *cl = (struct closure){ .fn = fn, .n = n, .k = k };
    return cl;
}
```

I added a function for allocating closures. We cannot put them on the stack if we intent to reuse stack frames, so they need to be allocated elsewhere. With `malloc()` it is going to be a little slow and some things will be annoying, but I will fix that with a costom allocator shortly.

We need a function for the continuation-closure `lambda res: k(n * res)`, and it looks like this:

```c
int fact_cont(int res, struct closure *cl)
{
    int n = cl->n;
    struct closure *k = cl->k;
    free(cl);

    // call continuation
    return k->fn(res * n, k);
}
```

The function frees its closure. We need to free the memory somewhere, and this is as good a place as any. It means that closures can only be called once—if you want more than that, you need better memory-management, and that is not the topic of this post.

Then we need the recursive function:

```c
int fact_rec(int n, struct closure *k)
{
    if (n <= 1) return k->fn(n, k);
    return fact_rec(n - 1, new_closure(fact_cont, n, k));
}
```

When we call this function the first time, we must provide it with a continuation that will return the normal way to C. I've called it `ret`:

```c
int ret(int n, struct closure *cl)
{
    free(cl);
    return n;
}
```

Now, we can wrap it all up in a normal C function that hides all the nasty closure/continuation stuff from the caller:

```c
int fact(int n)
{
    struct closure *done = new_closure(ret, 0, 0);
    return fact_rec(n, done);
}
```

Both `fact_rec` and `fact_cont` get a closure as their last argument, but they serve different purpose. For `fast_rec`, the closure is the continuation to call when it is done with its computation (or to pass along down the recursion if that is necessary). For `fast_cont`, the closure is the data for the function we invoke.

So, one is a continuation and the other is the closure for the continuation that we call. I just didn't bother with giving them different types, since it is exactly the same information we are passing along, and it is more hassle than it is worth to consider them separate things.

Still, there is a difference between continuations and the functions that use them. Some functions we call directly, but provide with a continuation, and other we invoke as closures. They do not do the same thing, one goes down the recursion and the other handles coming back up. And these functions do not need to take the same arguments. They do need to return the same type, the way we the recursive functions return the result of calling a continuation, but they can vary in their arguments.

If you are worried that we won't get tail-call optimisation when we muck about with function pointers, I'll put your worries to rest.

Here's `fact_cont` generated with `gcc`

```asm
fact_cont:
        push    r12
        push    rbp
        mov     ebp, edi
        mov     rdi, rsi
        push    rbx
        mov     ebx, DWORD PTR [rsi+8]
        mov     r12, QWORD PTR [rsi+16]
        imul    ebx, ebp
        call    free
        mov     rax, QWORD PTR [r12]
        mov     rsi, r12
        mov     edi, ebx
        pop     rbx
        pop     rbp
        pop     r12
        jmp     rax
```

There's a call to `free()`, when we free memory, but the call the the continuation is the `jmp rax` on the last line. It computes the function to jump to from the closure (so it can mess up the branch prediction), but it is still just a jump.

Here's `fact_cont` with `clang`:

```asm
fact_cont:                              # @fact_cont
        push    r14
        push    rbx
        push    rax
        mov     ebx, edi
        mov     r14, qword ptr [rsi + 16]
        imul    ebx, dword ptr [rsi + 8]
        mov     rdi, rsi
        call    free
        mov     rax, qword ptr [r14]
        mov     edi, ebx
        mov     rsi, r14
        add     rsp, 8
        pop     rbx
        pop     r14
        jmp     rax                             # TAILCALL
	
```

Again, you get a tail-call optimisation. Everything is fine.

# Fibonacci

Turning the Fibonacci computation into CPS-style C follows the same pattern.

We need to store a bit more in the closures. It varies from closure to closure what variables we need to remember, but the easiest is to make space for all of them in all closures. It shouldn't be hard to change that, but when I am playing around, I go for the easy solutions.

```c
struct closure {
    int (*fn)(int, struct closure *cl);
    int n, f1, f2;
    struct closure *k;
};
```

I'll also add a macro for calling closures, just to make that easier.

```c
#define call_closure(cl, n) cl->fn(n, cl)
```

For allocating closures I use this:

```c
struct closure *
new_closure(int (*fn)(int, struct closure *cl),
            struct closure closure)
{
    struct closure *cl = malloc(sizeof *cl);
    *cl = closure;
    cl->fn = fn;
    return cl;
}
```

It might look a bit odd that the function takes a closure `struct` as input, if that is what we are trying to allocate, but that `struct` will be stack allocated and it makes it easier to pass parameters to the closure using composite expressions. I can write code such as

```c
    return fib0(n - 2, new_closure(fib2,
               (struct closure){
                  .f1 = f1, .k = k
               }));
```

that way, and only have to provide the arguments I need to remember.

It's not that it is hard to provide defaults for all other parameters, but when you are messing around with this, you (or at least I) tend to add and remove parameters, and then it is tedious to have to update all the calls to the allocation function. This way, I don't have to do that.

We are going to need these functions:

```c
static int fib0(int n, struct closure *k);
static int fib1(int n, struct closure *cl);
static int fib2(int n, struct closure *cl);
static int ret(int n, struct closure *cl);
```

The `fib0` function, that takes a continuation `k`, is the one we call directly, while the others, that take closures `cl` are the continuations.

The `ret` continuation is the same as before; it is responsible for terminating the chain of continuations.

```c
static int ret(int n, struct closure *cl)
{
    free(cl);
    return n;
}
```

The `fib1()` continuation is the one that looked like this in Python:

```python
  lambda f1: return fib(n - 2, …)
```

and the `fib2()` is the one that does this:

```python
	lambda f2: k(f1 + f2)
```

But first the `fib0()` function. It will handle the base case, and call its continuation if it sees that, and otherwise it will recurse with `fib0(n - 1)` using `fib1` as the continuation.

```c
static int fib0(int n, struct closure *k)
{
    if (n <= 1) {
        return call_closure(k, n);
    } else {
        return fib0(n - 1, new_closure(fib1,
            (struct closure){ .n = n, .k = k }));
    }
}
```

Since `fib1()` needs to know `n` and the continuation `k`, that is what we bind in the closure. It will be called with the result of `fib0(n - 1, …)`, and then it needs to handle the `fib0(n - 2, …)` case, using `fib2()` as the continuation.

```c
static int fib1(int f1, struct closure *cl)
{
    struct closure *k = cl->k;
    int n = cl->n;
    free(cl);
    
    return fib0(n - 2, new_closure(fib2,
               (struct closure){ .f1 = f1, .k = k }));
}
```

We give `fib2()` the value `f1` and the continuation `k`, because that is what it will need. It will be called with the result of `fib0(n - 2, …)`. Then all it has to do is add its argument to `f1` and call the continuation.

```c
static int fib2(int f2, struct closure *cl)
{
    struct closure *k = cl->k;
    int f1 = cl->f1;
    free(cl);

    return call_closure(k, f1 + f2);
}
```

We can wrap all the CPS madness up in a function such as this:

```c
int fib(int n)
{
    return fib0(n, new_closure(ret, (struct closure){}));
}
```

# Cleaning up a bit…

This stuff is working, and the tail-calls mean we don't fill up the stack. Still, there are a couple of things that bother me.

One, the memory management is a problem. If I have to remember to free closures every time I call one, I can guarantee you that I will leak. I'm not good at remembering stuff like that, so I would prefer if I can get it more automated. Also, calling `malloc()` and `free()` for each closure creation/call is affecting performance. Those functions are a bit slow, and I think we can do better.

Another issue is the boilerplate code I write to handle closures. It is not that bad here, but while playing with different implementations, I kept changing which parameters the functions should take and how they should be called, and it was a drag changing practically the entire code every time I made a change. With a macro or two, I should be able to improve that. (I am not entirely sure if I improved things or made them worse, but I ended up making it different, at least).

First, I implemented an allocation pool. It handles chunks of memory of the same size, which makes it highly efficient, but there isn't anything particularly exciting about it, so I have put it in an appendix below.

The interface is this: you can create and free a pool

```c
struct mem_pool *new_mem_pool(size_t obj_size);
void free_mem_pool(struct mem_pool *pool);
```

and you can allocate and free chunks

```c
void *alloc_mem(struct mem_pool *pool);
void free_mem(struct mem_pool *pool, void *p);
```

There is a twist to `free_mem()`, though, that I exploit to the fullest. It doesn't touch the memory just yet. Until the next allocation, it leaves it alone. That means that I can free a closure when I call it, and the data is still available for the closure until it allocates a new closure. So, the memory is automatically freed, and you just have to be careful to get it before you allocate new closures (and I am nothing if not careful).

For the functions that we either call with continuations or invoke as closures, I made macros for defining them, so I could modify the arguments they get in a single location. They look like this:

```c
#define closure_func(F, ...)          \
    F(struct mem_pool *closure_pool_, \
      struct closure *cl_             \
      comma_if_not_nil(__VA_ARGS__)   \
      __VA_ARGS__ )

#define cps_func(F, ...)                        \
    F(struct mem_pool *closure_pool_,           \
      __VA_ARGS__ comma_if_not_nil(__VA_ARGS__) \
      struct closure *k_)
```

Closures will get the allocation pool and the closure as their first two arguments, and then any other arguments. The `comma_if_not_nil()` is to ensure that we only add a comma between the parameters we set here and the ones the user require if there actually are some user-defined arguments.

This is not as easy as you might think. The C standard doesn't have a way to detect zero or non-zero optional arguments. There are plenty of compiler extensions for it, because it is highly useful, but it isn't in the standard. Handling it here can be done with a bit of [macro hacking](https://mailund.dk/posts/macro-metaprogramming/).

```c
#define first(a, ...) a
#define second(a, b, ...) b

#define empty()
#define comma() ,

#define probe(p) second(p, comma)()
#define push_empty() -, empty

#define comma_if_not_nil(...) \
    probe(first(push_empty __VA_ARGS__)())
```

You might also have noticed that while closures get the closure as their second argument, functions that use continuations, the `cps_func()` functions, take the continuation as the last argument. There is a reason for that, and I'll get to it, but promise not to groan when we get there.

Then I added a macro for defining closures and an allocation function for them.

```c
#define args(...) __VA_ARGS__
#define define_closure(RET, ARGS, ...)           \
                                                 \
    struct closure                               \
    {                                            \
        RET closure_func((*fn_), ARGS);          \
        __VA_ARGS__;                             \
    };                                           \
                                                 \
    static struct closure *                      \
    alloc_closure(struct mem_pool *pool,         \
                  RET closure_func((*fn), ARGS), \
                  struct closure data)           \
    {                                            \
        struct closure *cl = alloc_mem(pool);    \
        *cl = data;                              \
        cl->fn_ = fn;                            \
        return cl;                               \
    }
```

The way my macros work, they need the name of the closure struct to be `struct closure`. I could easily change that, I suppose, but then I would need to add more parameters to the macros, and that would make them a bit ugly. If I ever need to handle different kinds of closures in the same compilation unit, I will come up with another solution.

The `alloc_closure()` function needs to know the type of the `struct closure` so I can invoke it with `.n = 1, .k = 42, .s = "foo"` syntax. I want that for the same reason as I mentioned above; it makes it a little easier to add or remove data from closures.

The memory pool, closure, and continuation have fixed names in the macros, `closure_pool_` `cl_`, and `k_`, respectively. That is also something I will exploit when I work with code. I don't want the user to access the closures directly, though. I might change how they are represented. So, I added a macro for that. Then I can change the layout and the macro, and the user code should still work.

```c
#define cl(var) cl_->var
```

You can define the closure type for the Fibonacci example like this:

```c
define_closure(
    int, args(int),     /* int fib(int n) */
    int n;              /* when I need to remember the initial n. */
    int f1;             /* the result of fib(n - 1). */
    int f2;             /* the result of fib(n - 2). */
    struct closure * k; /* continuation */
);
```

To allocate a closure, there is still some boilerplate code. When you call `alloc_closure` you need the pool (which we can get from `closure_pool_`) and you need to write `(struct closure){ … }` for the variables you want to store. We can use another macro to simplify this, or rather two macros, because I won't always use `closure_pool_` for the pool.

```c
#define new_closure_from_pool(P, F, ...) \
    alloc_closure(P, F, (struct closure){__VA_ARGS__})
#define new_closure(F, ...) \
    new_closure_from_pool(closure_pool_, F, __VA_ARGS__)
```

With this, you can write

```c
   new_closure(fib2, .f1 = f1, .k = cl(k))
```

to create a new `fib2()` closure that remembers `.f1 = f1` and `.k = cl(k)`, where `cl(k)` is the continuation `k` we get from the closure.

It's neat to simplify calls, but I am aware that if something goes wrong, it can go horribly wrong. In the long run, it might be a bad idea. But it is what I have right now.

When we call a closure we want to automatically free the memory (with the twist mentioned above), and we can also use a macro for that:

```c
#define call_closure(K, ...) \
    call_closure_with_pool(closure_pool_, K, __VA_ARGS__)
#define call_closure_with_pool(P, K, ...) \
    (free_mem(P, K),                      \
     (K)->fn_(P, K comma_if_not_nil(__VA_ARGS__) __VA_ARGS__))
```

The `call_closure_with_pool()` is for when we don't use a pool hardwired to the name `closure_pool_`, but that isn't often.

Now you can call a continuation simply like this

```c
    call_closure(k_, n);
```

and the memory will automatically be freed in the process.

When you call functions with a continuation, I have this hack:

```c
#define call(F) call_using_pool(closure_pool_, F)
#define call_using_pool(P, F) F(P, call_args_ /* beginning of args */
#define call_args_(...) __VA_ARGS__ comma_if_not_nil(__VA_ARGS__)
#define with_continuation(K) K)               /* end of args */
```

This is where you might start screaming. It lets you call a function with a continuation like this:

```c
    call(fib0)(n - 1) with_continuation(
        new_closure(fib1, .n = n, .k = k_));
```

and yes I realise that this is likely to bite me in my ass some day. But it ensures that the CPS are called with continuations, and it makes this explicit. (But to be honest, I just implemented it this way because I could).

This is the reason that the continuation goes last. Otherwise, I couldn't do this hack. (Which, admittedly, I probably shouldn't have done anyway).

Using these macros, the Fibonacci example looks like this:

```c
static int cps_func(fib0, int n);
static int closure_func(fib1, int f1);
static int closure_func(fib2, int f2);
static int closure_func(ret, int result);

static int closure_func(ret, int result)
{
    return result;
}

static int cps_func(fib0, int n)
{
    if (n <= 1)
        return call_closure(k_, n);

    return call(fib0)(n - 1) with_continuation(
        new_closure(fib1, .n = n, .k = k_));
}

static int closure_func(fib1, int f1)
{
    int n = cl(n) - 2; // get cl(n) before we allocate new closure
    return call(fib0)(n) with_continuation(
        new_closure(fib2, .f1 = f1, .k = cl(k)));
}

static int closure_func(fib2, int f2)
{
    return call_closure(cl(k), cl(f1) + f2);
}

int fib(int n)
{
    struct mem_pool *closure_pool_ = new_mem_pool(sizeof(struct closure));
    int result = call(fib0)(n) with_continuation(new_closure(ret, ));
    free_mem_pool(closure_pool_);
    return result;
}
```

The `fib()` function needs to set up the closure pool and free it after use, so it is not a tail-call, but it is just the setup frame. The rest of the functions are tail calls.

# Traversing trees

Despite what you might have been lead to believe, I am not particularly interested in computing Fibonacci numbers. But I am interested in traversing trees, without using the call-stack if I can avoid it. And it is because of this, that I started thinking about continuations.

I usually implement a tree traversal with an explicit stack and some `enum` that keeps track of what I have to do every time I get a stack frame.

But it can get tricky. You have to remember to push frames on the explicit stack in reverse order from how you would recurse, and there is always some book-keeping you didn't consider, and generally it is a mess if you need to do something complicated, like recursive edit-searching on a tree or in a suffix array.

Just implementing a stack is surely simpler than the continuation brouhaha, but it does get complicated at some point. With CPS code, maybe I could handle all the complexity once, like with the macros above, and then have a better solution?

I don't know. I haven't gotten that far. But it is what I intend to try.

Anyway, before I get ahead of myself, let's do a simple tree traversal.

We could implement a tree like this

```c
struct tree
{
    int i;
    struct tree *left, *right;
};

static struct tree *
new_tree(int i, struct tree *left, struct tree *right)
{
    struct tree *t = malloc(sizeof *t);
    *t = (struct tree){.i = i, .left = left, .right = right};
    return t;
}
```

and traverse it recursively

```c
static void recursive_traverse(struct tree *t)
{
    if (!t)
        return;

    recursive_traverse(t->left);
    printf("<%d> ", t->i);
    recursive_traverse(t->right);
}
```

and that way output the values in all the nodes

```c
int main(int argc, const char *argv[])
{
    struct tree *t = new_tree(3,
                              new_tree(2,
                                       new_tree(1, 0, 0),
                                       0),
                              new_tree(5,
                                       new_tree(4, 0, 0),
                                       new_tree(7, 0, 0)));
    recursive_traverse(t);
    putchar('\n');

    return 0;
}
```

If you feel up to it, you can implement a recursive function that applies a closure to each tree node. That's pretty simple to do. But I want to move on the more interesting things.

You can implement the same thing using an explicit stack. Here's a simple solution to that idea:

```c
enum state { VISIT, REPORT };
struct stack {
    enum state state;
    struct tree *t;
    struct stack *next;
};

void push(struct stack **stack,
           enum state state,
           struct tree *t)
{
    struct stack *s = malloc(sizeof *s);
    *s = (struct stack){ .state = state, .t = t, .next = *stack };
    *stack = s;
}

struct stack *pop(struct stack **stack)
{
    struct stack *s = *stack;
    *stack = s->next;
    return s;
}

void stack_traverse(struct tree *t)
{
    struct stack *stack = 0;
    push(&stack, VISIT, t);
    while (stack) {
        struct stack *next = pop(&stack);
        switch (next->state) {
            case VISIT:
                if (!next->t) break; // done
                
                // after we go left we should report.
                push(&stack, REPORT, next->t);
                push(&stack, VISIT, next->t->left);
                break;
                
            case REPORT:
                printf("<%d> ", next->t->i);

                // after reporting, we go right
                push(&stack, VISIT, next->t->right);
                break;
        }
        free(next);
    }
}
```

(I'm using `malloc()` and `free()` to implement a linked-list stack, but that is pure laziness. It is easy enough to get a faster solution.)

You will notice that it is not quite as simple as the recursion, and keep that in mind if you feel like complaining about the CPS solution later. When the language doesn't support what you want to do, you end up with a messier solution than if you go with what you have readily available.

You can implement the recursion with an explicit stack, of course you can, but there is some work to it. And I am not sure that the simple stack is easier than CPS. Especially when things get more complicated.

Let's do a CPS version. Our CPS functions will be called with a tree and a continuation, but the continuations won't take arguments. They will have everything they need in their closure, and "everthing they need" will be a tree and a continuation.

```c
define_closure(
    void, args(),        /* void traverse() (no arg for closures) */
    struct tree *t;      /* tree we are currently handling */
    struct closure * k;  /* continuation */
);
```

We will have a `visit()` CPS function and two closures, `report` for printing the node integer, and the usual `ret` to terminate the string of continuations.

```c
static void cps_func(visit, struct tree *t);
static void closure_func(ret);
static void closure_func(report);
```

The `ret` continuation is as simple as they come:

```c
static void closure_func(ret)
{
    ; // done
}
```

The `visit(t,k)` function will call the continuation if `t` is empty, and otherwise it will recurse on the left tree, creating a closure for reporting the node once this recursion is done.

```c
static void cps_func(visit, struct tree *t)
{
    if (!t)
        return call_closure(k_);
    else
        return call(visit)(t->left) with_continuation(
            new_closure(report, .t = t, .k = k_));
}
```

Finally, the report continuation will print the value in the tree it remembers in its closure and then recurse to the right, giving the recursion the continuation it has in its closure.

```c
static void closure_func(report)
{
    printf("<%d> ", cl(t)->i);
    struct tree *t = cl(t);
    call(visit)(t->right) with_continuation(cl(k));
}
```

As always, we need a function for setting up and tearing down all the closure stuff.

```c
static void cps_traverse(struct tree *t)
{
    struct mem_pool *closure_pool_ = new_mem_pool(sizeof(struct closure));
    call(visit)(t) with_continuation(new_closure(ret, ));
    free_mem_pool(closure_pool_);
}
```

This is the full CPS implementation:

```c
define_closure(
    void, args(),        /* void traverse() (no arg for closures) */
    struct tree *t;      /* tree we are currently handling */
    struct closure * k;  /* continuation */
);

static void closure_func(ret) { /* nothing */ }
static void closure_func(report);

static void cps_func(visit, struct tree *t)
{
    if (!t)
        return call_closure(k_);
    else
        return call(visit)(t->left) with_continuation(
            new_closure(report, .t = t, .k = k_));
}

static void closure_func(report)
{
    printf("<%d> ", cl(t)->i);
    struct tree *t = cl(t);
    call(visit)(t->right) with_continuation(cl(k));
}

static void cps_traverse(struct tree *t)
{
    struct mem_pool *closure_pool_ = new_mem_pool(sizeof(struct closure));
    call(visit)(t) with_continuation(new_closure(ret, ));
    free_mem_pool(closure_pool_);
}
```

It is 32 lines, including prototypes.

In comparison, the full stack implementation is 47 lines:

```c
enum state { VISIT, REPORT };
struct stack {
    enum state state;
    struct tree *t;
    struct stack *next;
};

void push(struct stack **stack,
           enum state state,
           struct tree *t)
{
    struct stack *s = malloc(sizeof *s);
    *s = (struct stack){ .state = state, .t = t, .next = *stack };
    *stack = s;
}

struct stack *pop(struct stack **stack)
{
    struct stack *s = *stack;
    *stack = s->next;
    return s;
}

void stack_traverse(struct tree *t)
{
    struct stack *stack = 0;
    push(&stack, VISIT, t);
    while (stack) {
        struct stack *next = pop(&stack);
        switch (next->state) {
            case VISIT:
                if (!next->t) break; // done
                
                // after we go left we should report.
                push(&stack, REPORT, next->t);
                push(&stack, VISIT, next->t->left);
                break;
                
            case REPORT:
                printf("<%d> ", next->t->i);
                // after reporting, we go right
                push(&stack, VISIT, next->t->right);
                break;
        }
        free(next);
    }
}
```

So, assuming we have the macros and allocators and all that jive, the CPS solution is not longer than the stack implementation. There shouldn't be much of a difference in performance either (I haven't tested because I haven't spent time properly optimising either solution).

Which solution is conceptually more difficult to work with is somewhat subjective, of course. Neither have the simple control flow of the direct recursion. But I will make the point that we shouldn't discard CPS solutions off-hand, for applications such as this.

# Iterators

There is another reason, beyond using less stack space, that I am interested in CPS or using an explicit stack. Sometimes, I want to suspend a traversal to report something, and then be able to resume it again.

When you traverse a data structure, searching for something perhaps, you want to report what you find. There are multiple options. Have a data structure you can write the results to, perhaps, but that ties the data structure tightly to the usages. Or use a call-back function (or even one of my closures) to call when you need to report something.

There is nothing *a priori* bad with that, but I often find it hard to follow the control flow if I use call-backs. Not a simple call-back for a tree traversal, I can wrap my head around that, but it never stays that simple. 

Say I want to map reads to a genome, so I have a function that will read a FASTQ file and invoke a call-back for each read. For each read, I then search in some index structure to find all approximate occurrences of the read. That's another call-back. So I need to provide a callback to the FASTQ parser, and that callback should provide another callback to the search algorithm, and you bet there will be more callbacks before I am done with this application.

Closures, if the language supports them, can help a lot here. But if you don't have closures where you can call a function with an anonymous function that can see the current scope, it is a *nightmare* to get such a callback based design to run smoothly.

No, I generally don't like this approach, and in languages like C, it is a no-go for iterating over data structures, search hits, or whatever.

In C, I want iterators. C doesn't provide that, so I want data that implements the iterator pattern instead.

Leaving continuations and closures for a second, here is an example of what I mean. I have a number of string search algorithms. They all search for a pattern `p` in a string `x`. They vary in complexity, but I have wrapped it all in an iterator structure, `cstr_exact_matcher` with a uniform interface. If I want to search using the algorithm `search(x, p)`, I can write:

```c
cstr_exact_matcher *matcher = search(x, p);
for (int m = cstr_exact_next_match(matcher);
     m != -1;
     m = cstr_exact_next_match(matcher)) {
    cstr_sslice match = CSTR_SUBSLICE(x, m, m + p.len);
    // do stuff with the match at index m
}
cstr_free_exact_matcher(matcher);
```

The `search(x, p)` call will create an iterator for me. When I call `cstr_exact_next_match(matcher)` I get the next match, or -1 if there are no more matches. And once I am done, I free the matcher with `cstr_free_exact_matcher(matcher)`.

Since both `next()` and `free()` operation is polymorphic, I implement it using function pointers.

```c
typedef int (*exact_next_fn)(cstr_exact_matcher *);
typedef void (*exact_free_fn)(cstr_exact_matcher *);

struct cstr_exact_matcher
{
    exact_next_fn next;
    exact_free_fn free;
    cstr_sslice x, p;
};
```

Concrete implementations will have this struct at the top of their data, so the polymorphic functions can get at it.

```c
int cstr_exact_next_match(cstr_exact_matcher *matcher)
{
    return matcher->next(matcher);
}

void cstr_free_exact_matcher(cstr_exact_matcher *matcher)
{
    matcher->free(matcher);
}
```

I have a macro for initialising the generic part

```c
#define MATCHER(NEXT, FREE, X, P)          \
    .matcher = (struct cstr_exact_matcher) \
    {                                      \
        .next = (exact_next_fn)(NEXT),     \
        .free = (exact_free_fn)(FREE),     \
        .x = (X),                          \
        .p = (P)                           \
    }
```

although that might be over-kill. The only useful thing it does is casting the function pointers to the polymorphic type.

Anyway, I can use it to initialise different search algorithms. Here's a naive O(nm) time algorithm:

```c
// macros for readability
#define x(S) ((S)->matcher.x.buf)
#define p(S) ((S)->matcher.p.buf)
#define n(S) ((int)(S)->matcher.x.len)
#define m(S) ((int)(S)->matcher.p.len)

// Naive O(nm) algorithm
struct naive_matcher_state
{
    cstr_exact_matcher matcher;
    int i;
};

static int naive_next(struct naive_matcher_state *s)
{
    for (; s->i < n(s); s->i++)
    {
        for (int j = 0; j < m(s); j++)
        {
            if (x(s)[s->i + j] != p(s)[j])
                break;
            if (j == m(s) - 1)
            {
                // a match
                s->i++; // next time, start from here
                return s->i - 1;
            }
        }
    }
    return -1; // If we get here, we are done.
}

cstr_exact_matcher *
cstr_naive_matcher(cstr_sslice x, cstr_sslice p)
{
    struct naive_matcher_state *state = cstr_malloc(sizeof *state);
    *state = (struct naive_matcher_state){
        MATCHER(naive_next, free, x, p),
        .i = 0};
    return (struct cstr_exact_matcher *)state;
}
```

and here's Knuth-Morris-Pratt:

```c
struct kmp_matcher_state
{
    struct cstr_exact_matcher matcher;
    int i, j;
    int ba[];
};

static int kmp_next(struct kmp_matcher_state *s)
{
    int i = s->i;
    int j = s->j;

    for (; i < n(s); ++i)
    {
        // move pattern down...
        while (j > 0 && x(s)[i] != p(s)[j])
            j = s->ba[j - 1];

        // match...
        if (x(s)[i] == p(s)[j])
        {
            j++;
            if (j == m(s))
            {
                // we have a match!
                s->j = s->ba[j - 1];
                s->i = i + 1;
                return i - m(s) + 1;
            }
        }
    }

    return -1;
}

cstr_exact_matcher *
cstr_kmp_matcher(cstr_sslice x, cstr_sslice p)
{
    struct kmp_matcher_state *state =
        CSTR_MALLOC_FLEX_ARRAY(state, ba, (size_t)p.len);
    *state = (struct kmp_matcher_state){
        MATCHER(kmp_next, free, x, p),
        .i = 0, .j = 0};
    compute_border_array(p, state->ba);
    return (struct cstr_exact_matcher *)state;
}
```

The important bit is not so much that I can get polymorphism, it is that I get an iterator over hits. I don't need to provide a data structure where the search algorithms put the results. I might not want all of them, or I don't want to allocate a structure if I have to move the data elsewhere afterwards. I just want to iterate over all the hits.

Iterators are a wonderful pattern, and for something as simple as searching for hits in a string, they are fairly simple to implement. You need to store a little bit of state in them, and whenever you are asked for the next element, you start from that search and move forward.

But it can get tricky if you want to traverse a recursive data structure (which, I suppose, is why we use the visitor pattern so much instead).

The state, when you suspend and resume a recursive traversal, includes the stack. If you cannot save the call stack, then you must use an explicit stack (or CPS, as we shall see).

Conceptually, there is no difference between saving a stack-state or any other type of state, but you do need to store it. Which means you have to do the traversal with an explicit stack. Direct recursion, even if you do not have stack overflow issues, is out the window.

I have implemented my share of explicit-stack-iterators, and it has never been fun. I hope that CPS can make it easier for me to implement suspend/resume iterators. And I think it does.

Here's a simple idea: make the functions return closures. When there is something to report, a `suspend()` closure will return control-flow to the caller. It will return a closure, from which we can get the value we wish the iterator to report, and which, if we call it, will resume the computation.

For traversing trees, closures could be defined like this:


```c
define_closure(
    struct closure *, args(),  /* closure *traverse() */
    struct tree *t;            /* tree we are currently handling */
    struct closure * k;        /* continuation */
);
```

It is the same as for the traversal, except that closures return closures now.

These are the functions and closures we need:

```c
static struct closure *cps_func(visit, struct tree *t);
static struct closure *closure_func(suspend);
static struct closure *closure_func(resume);
static struct closure *closure_func(ret)
{
    return 0; // no further processing
}
```

The `ret` continuation will return 0, indicating that there are no more closures to call. We will use that to recognise that the iteration is done.

The `visit()` function works as before, except that when it calls recursively it will pass along a continuation that will suspend.

```c
static struct closure *cps_func(visit, struct tree *t)
{
    if (!t)
        return call_closure(k_);
    else
        return call(visit)(t->left) with_continuation(
            new_closure(suspend, .t = t, .k = k_));
}
```

That means that when we return to a node from recursion to the left, `suspend()` is called. It will return a `resume()` closure.

```c
static struct closure *closure_func(suspend)
{
    return new_closure(resume, .t = cl(t), .k = cl(k));
}
```

The closure will hold the current tree, so we can get hold of it to report the node, and it will hold the closure `suspend` got `visit`—the one we need to call to return from the full recursion of the current tree.

When we resume, we have (probably) just reported the value in a node, so we need to recurse to the right, and the continuation we need to pass along is the one that will return to the function that called the recursion on the current tree. The `suspend` function stored that one in the closure.

```c
static struct closure *closure_func(resume)
{
    struct tree *right = cl(t)->right;
    return call(visit)(right) with_continuation(cl(k));
}
```

So, a call to `visit(t)` will, when we return from the recursion on the left, call `suspend()` so we can report the current node, and when we call the `resume()` closure we will recurse on the right and then return further up the recursion.

We can wrap all this up in an iterator. The iterator will hold the closure allocation pool and the closure to call to get the next value. That closure will also hold the current node.

```c
struct tree_itr
{
    struct mem_pool *pool;
    struct closure *next;
};

struct tree_itr *tree_iterator(struct tree *t);
bool has_more(struct tree_itr *itr);
int current_value(struct tree_itr *itr);
void next_value(struct tree_itr *itr);
void free_iterator(struct tree_itr *itr);

struct tree_itr *tree_iterator(struct tree *t)
{
    struct tree_itr *itr = malloc(sizeof *itr);
    itr->pool = new_mem_pool(sizeof(struct closure));
    // Run the first bit of the traversal.
    // This will run down to the left-most tree, collecting
    // closures along the way.
    itr->next = call_using_pool(itr->pool, visit)(t)
        with_continuation(new_closure_from_pool(itr->pool, ret, ));

    return itr;
}

bool has_more(struct tree_itr *itr)
{
    return !!itr->next;
}

int current_value(struct tree_itr *itr)
{
    // okay, admittedly, this is a bit ugly.
    return itr->next->t->i;
}

void next_value(struct tree_itr *itr)
{
    assert(itr->next);
    itr->next = call_closure_with_pool(itr->pool, itr->next);
}

void free_iterator(struct tree_itr *itr)
{
    free_mem_pool(itr->pool);
    free(itr);
}
```

With this machinery, you can iterate through all the nodes in the tree:

```c
struct tree_itr *itr = tree_iterator(t);
for (; has_more(itr); next_value(itr))
{
    printf("<%d> ", current_value(itr));
}
printf("\n");
free_iterator(itr);
```

The code might not be trivial, but (trust me) it is no worse than keeping track of an explicit stack.

And I can imagine the CPS approach being much simpler when you need to nest various types of recursions in a search. At least, it will be my first attempt when I need to implement that.

# Appendix: allocator

The closure pool allocator is quite simple, but I won't guarantee that it works perfectly. I have just whipped it up for these experiments and I have not tested it beyond running the code above.

Nevertheless, here it is.

An allocation pool consists of chunks of memory that look like this:

```c
struct mem_chunk
{
    // link to next free chunk
    struct mem_chunk *free;
    // the data in the chunk, max aligned so we can
    // put anything here.
    _Alignas(sizeof(max_align_t)) char data[];
};
```

There is a `free` pointer, so I can link the chunks into a free list, and then there is some data. In the structure, the data doesn't take up any memory, it will when we allocate blocks. We get the size as an argument to the allocation pool, and all we have to do here, is make sure that we can align the data. That is what the `_Alignas()` line is for.

The chunks are stored in a linked list of sub-pools. I use the sub-pools to extend the memory the pool can hold.

```c
#define SUBPOOL_SIZE 1024
struct mem_subpool
{
    struct mem_subpool *next;  /* next sub-pool */
    struct mem_chunk chunks[]; /* the sub-pool's chunks. */
    /* flex array because we don't know the size of chunks yet. */
};

struct mem_pool
{
    size_t obj_size;
    struct mem_subpool *pools;
    struct mem_chunk *free;
};
```

Then I have some macros to compute sizes of various things.

```c
#define HEADER_SIZE \
    offsetof(struct mem_chunk, data)
#define CHUNK_SIZE(OBJ_SIZE) \
    (HEADER_SIZE + OBJ_SIZE)
#define NEXT_CHUNK(P, OBJ_SIZE) \
    (struct mem_chunk *)((char *)P + CHUNK_SIZE(OBJ_SIZE))
#define CHUNK_TO_DATA(P) \
    ((void *)&(P)->data)
#define DATA_TO_CHUNK(P) \
    ((struct mem_chunk *)((char *)(P)-HEADER_SIZE))
```

`HEADER_SIZE` is the size of a chunk down to `data`, so the space used for the pointer and to get the data aligned. I suspect that this is just a pointer on most platforms, but I'm not sure.

`CHUNK_SIZE` gives us the size of a chunk. That is the size of the header and the size we need for the data.

`NEXT_CHUNK` gets us from a pointer to a chunk to the next chunk in contiguous memory. You need to cast `P` to `char *` because that is the unit the sizes are in.

`CHUNK_TO_DATA` gets you the data inside a chunk, while `DATA_TO_CHUNK` takes a pointer to the data in a chunk and gives us a pointer to the chunk.

I inline `alloc_mem()` and `free_mem()`, and they look like this:

```c
static inline void *
alloc_mem(struct mem_pool *pool)
{
    if (!pool->free)
    {
        struct mem_subpool *spool =
            new_subpool(pool->obj_size, pool->pools);
        pool->free = (struct mem_chunk *)spool->chunks;
    }

    struct mem_chunk *p = pool->free;
    pool->free = pool->free->free;

    return CHUNK_TO_DATA(p);
}

static inline void free_mem(struct mem_pool *pool, void *p)
{
    struct mem_chunk *chunk = DATA_TO_CHUNK(p);
    chunk->free = pool->free;
    pool->free = chunk;
}
```

For allocating, if there are no free chunks I allocate a new sub-pool, and the top of the sub-pool is the new free list. Then I take the first free chunk, update the free list, and return a pointer to the data in chunk. For freeing, I get the chunk that contains the data and I add it to the free list.

I don't embed the user data and the free list in the same memory, something I would usually do. The reason, of course, is that I don't want to touch the user data until the next allocation. That is, kinda, something the closure code relies on.

Allocating a sub-pool is the trickiest code, but it is not too bad.

```c
struct mem_subpool *
new_subpool(size_t obj_size, struct mem_subpool *next)
{
    struct mem_subpool *pool =
        malloc(offsetof(struct mem_subpool, chunks) +
               SUBPOOL_SIZE * CHUNK_SIZE(obj_size));

    struct mem_chunk *chunk = (struct mem_chunk *)pool->chunks;
    for (int i = 0; i < SUBPOOL_SIZE - 1;
         chunk = NEXT_CHUNK(chunk, obj_size), i++)
    {
        chunk->free = NEXT_CHUNK(chunk, obj_size);
    }
    chunk->free = 0;

    pool->next = next;
    return pool;
}
```

The size calculation is the tricky bit (and it might be wrong, so don't use this code for something important). Then we need to initialises the free-list in the sub-pool, which means jumping from chunk to chunk. Here we need `NEXT_CHUNK` to work out the distance between chunks. Other than that, I don't think there is much to it.

Allocating and freeing a full pool is trivial.

```c
struct mem_pool *new_mem_pool(size_t obj_size)
{
    struct mem_pool *pool = malloc(sizeof *pool);
    pool->obj_size = obj_size;
    pool->pools = new_subpool(obj_size, NULL);
    pool->free = (struct mem_chunk *)pool->pools->chunks;
    return pool;
}


void free_mem_pool(struct mem_pool *pool)
{
    struct mem_subpool *sp = pool->pools;
    while (sp)
    {
        struct mem_subpool *next = sp->next;
        free(sp);
        sp = next;
    }
    free(pool);
}
```


