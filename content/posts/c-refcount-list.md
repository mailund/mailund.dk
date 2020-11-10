+++
title = "Reference counting lists in C"
date = 2020-10-30T06:59:36+01:00
draft = false
tags = []
categories = []
+++

I was playing with reference counting garbage collection last week, for something I want to add to my C pointers book. That chapter is still far in the future, and moving further into the future as the book seems to grow in front of me, but one day I will get to it. And by then, I have to have figured out some design issues that I ran into.

## Reference counting garbage collection

The idea is simple enough. Instead of having some designated “owner” of an object, responsible for freeing it when we no longer need it, we keep a count of how many references we have to the object. We increment the reference count when we make another reference, and we decrement it again when we remove a reference. No problem there.

I have seen implementations like the one below several places, and it gives an idea about what we are aiming at (but it has some issues that I will describe below).

```c

#include <stdlib.h>
#include <stdio.h>

typedef void (*deallocator)(void *);
struct refcount {
  int count;
  deallocator free;
};

void *rc_malloc(size_t size, deallocator free)
{
  struct refcount *p = malloc(sizeof(struct refcount) + size);
  *p = (struct refcount){ .count = 1, .free = free };
  return p + 1;
}

void rc_free(struct refcount *rc)
{
  rc->free(rc + 1);
}

void *incref(void *p)
{
  if (!p) return p;
  struct refcount *rc = (struct refcount *)p - 1;
  rc->count++;
  return rc + 1;
}

void *decref(void *p)
{
  if (!p) return p;
  struct refcount *rc = (struct refcount *)p - 1;
  if (rc && --(rc->count) < 1) {
    rc_free(rc);
    return 0;
  }
  return rc + 1;
}

void print_free(void *p)
{
  int *ip = p;
  printf("freeing %d\n", *ip);
}

int main(void)
{
  int *p = rc_malloc(sizeof *p, print_free);
  *p = 42;

  // Add a reference
  int *p2 = incref(p);

  decref(p); // This doesn't delete the object
  decref(p2); // This does

  return 0;
}
```

An object that we manage with reference counting has a count and a function we should call when it should be freed.

```c
typedef void (*deallocator)(void *);
struct refcount {
  int count;
  deallocator free;
};
```

I used `int` for `count`, although it is never supposed to be negative. A signed integer makes it easier to discover if I managed to get an underflow—but an `assert()` might be in order to prevent it from happening. But there is also another reason. It can be faster to work with signed than unsigned integers in C. The standard requires that unsigned integers work with modular arithmetic, but signed integers can work as whatever the hardware says it should work like. The compiler thus might have to emit extra code if we insist on working with unsigned integers. Here, I don’t expect to reference more than I can count in the positive part of an integer (and if I did, I could go for a larger integer type), so I might as well get faster code *and* code that is easier to debug.

There might be more functions you need beyond `free()`, and in that case the function pointer should be a pointer to a struct functions, but for our purposes this suffices. The `free()` function should decrement other counts, if the object holds references, but I get to that later.

The main problem with this code has nothing to do with reference counting, I just wanted to bring it up here, because I have seen such code at least a handful of times while googling around for reference counting examples. When we allocate memory, we allocate a number of bytes (well, `sizeof(char)`) similar to how we use `malloc()`, but the `rc_malloc()` function first allocates space for the reference counting structure. It initialises that, and returns the address after the struct. When the `p` pointer has type `struct refcount *`, the address `p + 1` is the one right after the structure. The `rc_free()` function will be called with a pointer to the `struct refcount`, but the user-provided `free()` function should be called with the address the user actually got, so there we use a `rc + 1` pointer addition as well. When we increment the count in `incref()`, that is called with the user’s address, so we need to go one `struct refcount` back to get the counter, and similarly with `decref()`.

I made `incref()` and `decref()` take `void *` and input and return `void *` to avoid casting in the code that uses reference counting. You can assign any data pointer to `void *` and back, without explicit casts, so going through `void *` means that we can use any type with reference counting (assuming, of course, the data was allocated with reference counting). Type-safety is out the window, of course, but it will be anyway if we want to work with generic memory allocation.

I haven’t handled `malloc()` errors—I get to error handling much later—but that isn’t the problem. The problem is that you have no idea about whether what the user wants to put after the reference counting struct aligns there. That is what bothered me every time I saw it. Now, probably, the function pointer has maximum alignment, and then we don’t have a problem, but we do not have any guarantees here. You can align anything at the address you get from `malloc()`, but *not* anything at an arbitrary offset from it.

I will probably end up with some code that looks like this, just with a fix for the alignment issue, but for everything below, I will make things simpler by embedding the `refcount` struct in data I allocate. If I explicitly put such a struct at the beginning of my data, then I can cast my data to it and get the `struct refcount`, and whatever comes after it in my memory layout is correctly aligned.

So, my reference counting code, in all its simplicity, will look like this:

```c
typedef void (*deallocator)(void *);
struct refcount {
  int count;
  deallocator free;
};

void *incref(void *p)
{
  struct refcount *rc = p;
  if (rc) rc->count++;
  return rc;
}

void *decref(void *p)
{
  struct refcount *rc = p;
  if (rc && --(rc->count) < 1) {
    rc->free(rc);
    return 0;
  }
  return rc;
}
```

It is simple enough that there shouldn’t be any issues. And there isn’t, if you use it correctly. Of course, what “use it correctly” means, that is the problem.

## Lists, take one

The example I was working on for my book was a linked lists. It doesn’t get simpler than that, so it is a good starting point. Turned out, though, that this quickly got complicated—so I am happy I didn’t start with something harder, like string graphs which were my first idea.

Well, it is not that lists are that complicated, not at all, but I wanted to implement something that looked like lists in a functional language, and that escalated quickly.

If we completely ignore memory management, then we can define a list like this:

```c
struct link {
  struct link * const next;
  int           const value;
};

typedef struct link *list;
#define NIL 0
#define is_nil(x) ((x) == NIL)

list cons(int car, list cdr)
{
  list new_link = malloc(sizeof *new_link);
  struct link link_data = {
    .next  = cdr,
    .value = car
  };
  memcpy(new_link, &link_data, sizeof *new_link);
  return new_link;
}
```

I have made the two members of the `struct link` `const` because I want lists to be immutable—as they are in a pure functional language. I define the type `list` to be pointers to links, and I define the empty list, `NIL` to be the NULL pointer (something that I will change shortly). The function `const()`, with a naming convention from LISP, makes a new link, sets the value to `car` and the `next` pointer to `cdr`. The `link_data`/`memcpy()` code is there so I can write to the `const` members in the link.

We could write a function to get the length of a list:

```c
int length(list x, int acc)
{
  if (is_nil(x)) return acc;
  else return length(x->next, acc + 1);
}
```

or to reverse a list:

```c
list reverse(list x, list acc)
{
  if (is_nil(x)) return acc;
  else return reverse(x->next, cons(x->value, acc));
}
```

To reverse, you should start with `NIL` as the accumulator:

```c
  list y = reverse(x, NIL);
```

Both are tail-recursive, and an optimising compiler will turn them into loops. The `length()` function doesn’t allocate any new links, so it should be easy to handle when we get to memory management (one would think), but the `reverse()` function creates new links. It also returns the first link in the list it creates, so we will not leak memory if we handle the memory there.

You can concatenate two lists with

```c
list concat(list x, list y)
{
  if (is_nil(x)) return y;
  else return cons(x->value, concat(x->next, y));
}
```

and like `reverse()` it creates new links, but it returns the first of them when it is done, so we have a handle on them if we need to free them.

The `concat()` function isn’t tail recursive, but we could make it so:

```c
list prepend_list(list x, list acc)
{
  if (is_nil(x)) return acc;
  else return prepend_list(x->next, cons(x->value, acc));
}
list concat_tr(list x, list y, list acc)
{
  if (is_nil(x)) return prepend_list(acc, y);
  else return concat_tr(x->next, y, cons(x->value, acc));
}
```

The accumulator should start as `NIL`:

```c
  list z = concat_tr(x, y, NIL);
```

Here we have a bit of a problem with garbage collection. We create new links with `cons()` in `concat_tr()`, but we consume them again in `prepend_list()`. When we go from `x` to `x->next` in `prepend_list()` we lose a reference to `x`, and we do not have another reference to it, because we created it going down the recursion in `concat_tr()`.

The minimum I want to handle, with reference counted lists, are functions such as these. And so far, I haven’t found a simple and elegant solution…

### cons()

The first place to dig in is of course `cons()`. This is where we create links. We can easily add reference counting to links, but as soon as we do that, we need to work out how `cons()` should behave with respect to them.

We add a `struct refcount` to the links, and it has to go at the top for the memory layout to match the increment and decrement functions.

```c
struct link {
  struct refcount     rc;
  struct link * const next;
  int           const value;
};
```

We need a function that frees a link—and decrements the `next` link—and we need to initialise the reference count in `cons()`.

```c
void free_list(list x)
{
  decref(x->next);
  free(x);
}

list cons(int car, list cdr)
{
  list new_link = malloc(sizeof *new_link);
  struct link link_data = {
    .rc    = (struct refcount){
      .count = 1,          // Zero or one?
      .free  = (deallocator)free_list
    },
    .next  = incref(cdr), // Or maybe not incref?
    .value = car
  };
  memcpy(new_link, &link_data, sizeof *new_link);
  return new_link;
}
```

The `free_list()` can start a recursive cascade of decrements/freeing, with long lists, that can exceed the stack. I think I have a solution for that, but I will ignore it for now.

We have two choices to make now. Should a new link have a reference count of one or zero? We do not have a reference to it as such, which would argue that it should be zero, but on the other hand, if our idea is that objects with zero references to them should be deleted, we shouldn’t have links with zero references. And what about `next`? Should we increment its count or shouldn’t we?

If we write

```c
  list x = // …some list…
  list y = cons(42, x);
```

then both `y` and `x` have access to the first link in `x`, so the link that `x` points to shouldn’t be freed before `y` is. That tells us that we probably want to add a reference to a link when it is set to the `next` link in another. But in that case, if `cons()` returns a link with a reference count of one, then

```c
  list x = cons(1, cons(2, NIL));
```

will give us a list where the first link has a reference count of one, because that is what `cons()` gives us, and the second has a reference count of two, because `cons(2, NIL)` gives us one with a count of one, and we increment it.

There is no single correct solution, but the one we have now is clearly wrong. Either we add a reference to `cdr` in `cons()`, or we don’t add a reference to the link that we return.

Generally, when we have a function that gets a reference, we have to decide on whether it “has a reference”, which should be reflected in the reference count, or it just has a pointer to the object. The same goes when we put a pointer into a structure, but there it is an easier choice to make. If a structure holds a reference to an object, then it should count as a reference. But it reflects back to the first choice. Does `cons()` get a reference to `cdr`, that it can then give to the new link, so `cdr`’s reference count stays the same? Or does it get a pointer ro `cdr`, but it has to increment the counter to make the new link hold a reference?

Tentatively, I will say that it gets a pointer and has to increment it when it puts `cdr` in the new link. If I increment the reference count for `cdr`, then I don’t want to return a link that already has a count. If I do that, then the second link in the list `x` above has one too many references. There is only one way to get to the second link, through the first in `x`, so it is incorrect that the second link has `count` two. If I `decref(x)`, the first link goes from count one to zero, and will be freed, and then the deallocator will decrement the count of `next`, and it will go from two to one and not be freed. That is clearly a leak. So, at least as far as `cons()` is concerned: It doesn’t get references to its input, and it returns an object without references. If you get a value from `cons()`, and you want to hold on to it, you must `incref()` it. If you don’t, you must delete it. So we should have written

```c
  list x = incref(cons(1, cons(2, NIL)));
```

above. Or, if we wanted to waste time and throw away the result of the list construction, we could have written

```c
  decref(cons(1, cons(2, NIL)));
```

Here, the reference count would go to -1, but our `decref()` can handle that if it comes to it.

It is completely arbitrary that we have to increment after `cons()`, and not make `cons()` do it, and I might change my mind later, but if `cons()` add a reference to its result, then it shouldn’t increment `cdr`, and if it increments `cdr` it shouldn’t add a referent to its result.

With these design choices, the `length()`, `reverse()` and `concat()` functions above will work, and not leak memory, if we use them like this:

```c
  list x = incref(cons(1, cons(2, cons(3, NIL))));
  list y = incref(reverse(x, NIL));
  list z = incref(concat(x, y));

  decref(x); decref(y); decref(z);
```


We don’t really share a lot of links here, but the last half of `z` is the list `y`, so we do share some. They are not completely independent lists.

The `concat_tr()` will leak memory. There, we create links that are never dereferenced. I will get to that, but first, we need to handle errors.

## Error handling

When we `malloc()` in `cons()` we assume that the allocation doesn’t fail. But, of course, `malloc()` can fail, and we can get a NULL pointer from it. If we do, we certainly shouldn’t write into the result.

We can update `cons()` to return NULL if `malloc()` fails:

```c
list cons(int car, list cdr)
{
  list new_link = malloc(sizeof *new_link);
  if (new_link) {
    struct link link_data = {
      .rc    = (struct refcount){
        .count = 0,
        .free  = (deallocator)free_list
      },
      .next  = incref(cdr),
      .value = car
    };
    memcpy(new_link, &link_data, sizeof *new_link);
  }
  return new_link;
}
```

Easy-peasy, except that now

```c
  list x = cons(1, cons(2, cons(3, NIL)));
```

can leak memory. If a `malloc()` fails, we have a reference to a `cdr` that should be freed. If `cdr` doesn’t have any other references, we have to get rid of it. If it does have at least one reference, we shouldn’t. If we want to be able to write expressions such as this, then `cons()` must handle `cdr`’s memory correctly.

Now, errors in `cons()` leads me to another issue. I am using NULL to mean the empty list, which means that I will not be able to differentiate between a list that is empty and an allocation error. That clearly isn’t a good idea. So I will define the empty list as an actual object, and set aside NULL to mean error.

```c
struct link NIL_LINK = { .rc = { .count = 1 } };
#define NIL (&NIL_LINK)
#define is_nil(x)   ((x) == NIL)
#define is_error(x) ((x) == 0)
```

If the empty list link is handled correctly by all our functions, it will never be freed. Every time we add a reference to it, we increment the counter, and it starts at one and should never go below that.

Now, returning NULL from `cons()` indicates that we have an error. But if we have an error, we should free `cdr`’s memory (unless there are other references to it).

Our mechanism for freeing is decrementing, so that is what we should use for `cdr`. If we just go ahead and free, we get into trouble if we have the references. We can handle `cdr` both in cases of errors and success by incrementing it at the top of the function and decrementing it at the end of the function:

```c
list cons(int car, list cdr)
{
  if (is_error(cdr)) return cdr;

  incref(cdr);
  list new_link = malloc(sizeof *new_link);
  if (new_link) {
    struct link link_data = {
      .rc    = (struct refcount){
        .count = 0,
        .free  = (deallocator)free_list
      },
      .next  = incref(cdr),
      .value = car
    };
    memcpy(new_link, &link_data, sizeof *new_link);
  }
  decref(cdr);
  return new_link;
}
```

I added a test at the top of the function, so we abort if we start with an error. That is the easiest way to propagate errors back through function calls and not handle special cases everywhere.

If we increment `cdr` and we have an error, we decrement it again, and if we didn’t have any other references to it, it is freed. If we didn’t have an error, we have incremented it twice—at the top of the function and when we inserted it into the new link—and everything is as it is supposed to be.

If you want to go for the alternative solution, where new links start with a reference count of one, you can remove the `incref(cdr)` at the top, but then you have to make sure that every time you call `cons()` with a list, you increment first.

## Enter/exit inc/dec

Can we use the same approach to handle memory management for the other functions? Maybe get error handling on top of it?

Yes, but it gets a little ugly.

Let us take `length()` first. It is the simplest. It takes one list input, `x`, and without error handling or memory management, it looks like this:

```c
int length(list x, int acc)
{
  if (is_nil(x)) return acc;
  else return length(x->next, acc + 1);
}
```

If we have a list with a reference, it works as it should.

```c
  list x = cons(1, cons(2, cons(3, NIL)));
  int len = length(x, 0);
```

but what if we write

```c
  int len = length(cons(1, cons(2, cons(3, NIL))), 0);
```

We get the length, but we have lost all references to the links, if `length()` doesn’t free them.

Ok, so we do the same with `length()` as we did with `cons()`:

```c
int length(list x, int acc)
{
  assert(!is_error(x));

  incref(x);
  int retval;
  if (is_nil(x)) retval = acc;
  else retval = length(x->next, acc + 1);
  decref(x);

  return retval;
}
```

It is no longer tail recursive, which bothers me slightly, but it works. One of the reasons it isn’t tail recursive is that we need to decrement `x` after the recursion, and that will also be a problem if we turned the function into a loop. If we cannot easily write the function tail-recursive, then we will also have problems writing it iteratively… so we need to find a solution for that.

Much worse is the next function, `reverse()`:

```c
list reverse(list x, list acc)
{
  incref(x); incref(acc);
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  list retval;
  if (is_nil(x)) retval = acc;
  else retval = reverse(x->next, cons(x->value, acc));

  decref(x); decref(acc);
  return retval;
}
```

We have some error handling at the top, after we increment the input, but that is not the problematic part. The problem is the termination when we should return `acc`. We build `acc` using `cons()` as we go down the recursion, so it will not have any references when we call `reverse()` the last time. When we increment the count on `acc` it goes to one, which is fine, but just before we return `retval`, we decrement `acc`, which takes the count to zero, and then we free it. We are returning a pointer to freed memory. That, obviously, is a problem.

Ok, no problem, we can just return `acc` without decrementing it (and only decrement `x`):

```c
list reverse(list x, list acc)
{
  incref(x); incref(acc);
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  list retval;
  if (is_nil(x)) { decref(x); return acc; }
  else retval = reverse(x->next, cons(x->value, acc));

  decref(x); decref(acc);
  return retval;
}
```

Not so fast, though. We have incremented, but not decremented, `acc`. If it is the result of a `cons()`, the reference count was zero when we got it, but now we return it with a count of one. That is one reference too many!

So, we are in the pickle that if we decrement it, we lose it, and if ew don’t, we leak memory. **I don’t have a good solution for this yet!** I was sort of hoping that someone would have some advice.

We could think about going back and have `cons()` return objects with a reference count of one, and then have all other functions that create lists do the same. If we do that, then functions should never return a value with a reference count of zero, and then we don’t have the problem with accidentally freeing a value before we return it.

It does work, but now you have to remember to `incref()` *every single argument* when you call a function. The `length()` and `reverse()` functions would look like this

```c
int length(list x, int acc)
{
  assert(!is_error(x));

  int retval;
  if (is_nil(x)) retval = acc;
  else retval = length(incref(x->next), acc + 1);
  decref(x);

  return retval;
}

list reverse(list x, list acc)
{
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  list retval;
  if (is_nil(x)) retval = incref(acc);
  else retval = reverse(incref(x->next), cons(x->value, incref(acc)));

  decref(x); decref(acc);
  return retval;
}
```

and you could use them like

```c
  list x = cons(1, cons(2, cons(3, incref(NIL))));
  list y = reverse(incref(x), incref(NIL));
```

Notice that you *have* to increment `NIL` here, or you will attempt to free a global variable. 

The concatenation function would look like:

```c
list concat(list x, list y)
{
  if (is_error(x) || is_error(y)) {
    decref(x); decref(y);
    return 0;
  }

  list retval;
  if (is_nil(x)) retval = incref(y);
  else retval = cons(x->value, concat(incref(x->next), incref(y)));

  decref(x); decref(y);
  return retval;
}
```

where, again, you have to remember to `incref()` when you call a function. But only when you have a reference, and not when you use the result of another call.

To me, having to remember to increment all the right places when I call a function just spells trouble. I want the functions to handle it, not the caller. And that, unfortunately, means that new objects, returned from a function, must have reference count zero, which in turn means that there is a problem when we return an argument. The function can increment the count to one, but it needs to go down to zero again when we return, and it needs to go down to zero without freeing the object.

## Protecting (and unprotecting)

This is what I came up with (*and I am not happy with it*): Add two other operations for protecting and unprotecting objects from garbage collection.

```c
void *protect(void *p)
{
  struct refcount *rc = p;
  assert(rc);
  rc->count++;
  return rc;
}

void *unprotect(void *p)
{
  struct refcount *rc = p;
  assert(rc && rc->count > 0);
  rc->count--;
  return rc;
}
```

They are essentially `incref()` and `decref()`, but they should never be called with a NULL pointer, and `unprotect()` doesn’t free its input if the reference reaches zero.

Now, our functions can look like

```c
int length(list x, int acc)
{
  assert(!is_error(x));
  incref(x);

  int retval;
  if (is_nil(x)) retval = acc;
  else retval = length(x->next, acc + 1);

  decref(x);
  return retval;
}

list reverse(list x, list acc)
{
  incref(x); incref(acc);
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  list retval;
  if (is_nil(x)) retval = protect(acc);
  else retval = protect(reverse(x->next, cons(x->value, acc)));

  decref(x); decref(acc);
  return unprotect(retval);
}

list concat(list x, list y)
{
  incref(x); incref(y);
  if (is_error(x) || is_error(y)) {
    decref(x); decref(y);
    return 0;
  }

  list retval;
  if (is_nil(x)) retval = protect(y);
  else retval = protect(cons(x->value, concat(x->next, y)));

  decref(x); decref(y);
  return unprotect(retval);
}
```

and they correctly handle garbage collection and errors.

It still bothers me that they are not tail recursive, but with `protect()` and `unprotect()` can I make them so (and consequently, I can write a loop version if I so desired).

Take `length()`:

```c
int length(list x, int acc)
{
  assert(!is_error(x));
  incref(x);
  if (is_nil(x)) {
    decref(x);
    return acc;
  }
  else {
    list next = protect(x->next);
    decref(x);
    return length(unprotect(next), acc + 1);
  }
}
```

We have to `incref(x)` the argument, which also means that we must `decref(x)` it. Yes, incrementing and decrementing leaves us where we started, but if `x` is an object we should free, the `decref(x)` will handle it, so the alternative to counting up and then down is to check the count in `x` and freeing it. This is just as simple. The accumulator is an integer, so it is not an object we should protect or free, but for the recursive call, we need to get the `next` pointer in `x`, and we need to protect it if `x` is freed in `decref(x)`. So we protect it, decrement `x`, and then unprotect in the recursive call. Pretty it isn’t, but it works.

With `reverse()` we have two input lists to increment/decrement. In case of error input, this will free them. In the base case of the recursion, we should return the accumulator, so we cannot decrement it. Instead, we unprotect it, because we do have to lower its reference count since we increased it.

In the recursive case, we need the `next` link, protected of course, since we might free `x`, and in the recursive call, we must unprotect the protected `next` and the accumulator that we `incref()`’ed at the top of the function.

```c
list reverse(list x, list acc)
{
  incref(x); incref(acc);
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  if (is_nil(x)) {
    decref(x);
    return unprotect(acc);
  } else {
    list next = protect(x->next);
    int value = x->value;
    decref(x);
    return reverse(unprotect(next),
                   cons(value, unprotect(acc)));
  }
}
```

Here is `concat()`:

```c
list concat(list x, list y)
{
  incref(x); incref(y);
  if (is_error(x) || is_error(y)) {
    decref(x); decref(y);
    return 0;
  }

  if (is_nil(x)) {
    decref(x);
    return unprotect(y);
  }else {
    list next = protect(x->next);
    int value = x->value;
    decref(x);
    return cons(value,
                concat(unprotect(next),
                       unprotect(y)));
  }
}
```

and the tail recursive version:

```c
list prepend_list(list x, list acc)
{
  incref(x); incref(acc);
  if (is_error(x) || is_error(acc)) {
    decref(x); decref(acc);
    return 0;
  }

  if (is_nil(x)) {
    decref(x);
    return unprotect(acc);
  } else {
    list next = protect(x->next);
    int value = x->value;
    decref(x);
    return prepend_list(unprotect(next),
                        cons(value, unprotect(acc)));
  }
}
list concat_tr(list x, list y, list acc)
{
  incref(x); incref(y); incref(acc);
  if (is_error(x) || is_error(y) || is_error(acc)) {
    decref(x); decref(y); decref(acc);
    return 0;
  }

  if (is_nil(x)) {
    decref(x);
    return prepend_list(unprotect(acc), unprotect(y));
  } else {
    list next = protect(x->next);
    int value = x->value;
    decref(x);
    return concat_tr(unprotect(next),
                     unprotect(y),
                     cons(value, unprotect(acc)));
  }
}
```

Compared to their original versions, they are not pretty.

## Prettifying?

Aside from efficiency, I have two problems with this solution. It takes a lot of mental energy to keep track of the protection/unprotection, because you have to remember to decrement the right objects, and only the right objects. And the code is ugly.

I can improve on the second, to some degree, if I go crazy with macros. My idea is this: I collect the input variables in an array, so I can automate incrementing and decrementing of those.

This macro creates an array with the variables you give it. It should go at the top of a function. I know, I know, it is frowned upon to declare variables in macros, but I need it here. I picked a name with an initial underscore—which goes against the rules—but it is my way to get around the problem.

```c
#define REFCOUNT_VARS(...) \
  void *_refcount_vars_[] = { __VA_ARGS__ };
```

Now I can write macros that increment and decrement all the variables.

```c
#define REFCOUNT_ALL_VARS(func)              \
  do {                                       \
    for (int i = 0;                          \
         i < sizeof _refcount_vars_ /        \
             sizeof *_refcount_vars_;        \
         i++) {                              \
      func(_refcount_vars_[i]);              \
    }                                        \
  } while(0)

#define INCREF_VARS()                        \
  REFCOUNT_ALL_VARS(incref)
#define DECREF_VARS()                        \
  REFCOUNT_ALL_VARS(decref)
```

I can write another that runs through them, and tests if any of them is NULL. That is how we indicate errors, so if one is NULL, we decrement all input references and return NULL.

```c
#define CHECK_INPUT(func)                    \
  do {                                       \
    for (int i = 0;                          \
         i < sizeof _refcount_vars_ /        \
             sizeof *_refcount_vars_;        \
         i++) {                              \
      if (!_refcount_vars_[i]) {             \
        DECREF_VARS();                       \
        return 0;                            \
      }                                      \
    }                                        \
  } while(0)
```

We wrap these up in a macro, `ENTER`, that you should call at the beginning of all functions, with the variables you want to manage with reference counting.

```c
#define ENTER(...)                           \
    REFCOUNT_VARS(__VA_ARGS__);              \
    INCREF_VARS();                           \
    CHECK_INPUT();
```

We should also safely return from functions, so we want some help with that as well. It is easy to write a macro that decrements the input before we return

```c
#define RETURN(expr) \
  do { DECREF_VARS(); return (expr); } while(0)
```

but we can’t use it if we need to protect some of the variables. For that, here is a macro that takes variables to protect, call `protect()` on all of them, then decrement those variables we declared with `ENTER()`, and unprotect then afterwards.

```c
#define REFCOUNT_ALL_PROTECTED(func)         \
  do {                                       \
    for (int i = 0;                          \
         i < sizeof _refcount_protected_ /   \
             sizeof *_refcount_protected_;   \
         i++) {                              \
      func(_refcount_protected_[i]);         \
    }                                        \
  } while(0)

#define PROTECTED_EXIT(...)                          \
  do {                                               \
    void *_refcount_protected_[] = { __VA_ARGS__ };  \
    REFCOUNT_ALL_PROTECTED(protect);                 \
    DECREF_VARS();                                   \
    REFCOUNT_ALL_PROTECTED(unprotect);               \
  } while(0)

```

If you want to return, you can combine the protection and return statement with:

```c
#define RETURN_PROTECTED(expr, ...) \
  do { PROTECTED_EXIT(__VA_ARGS__); return (expr); } while(0)
```

With these macros, the `length()` function looks like:

```c
int length(list x, int acc)
{
  ENTER(x);
  if (is_nil(x)) RETURN(acc);
  else {
    list next = x->next;
    RETURN_PROTECTED(
      length(next, acc + 1),
      next
    );
  }
}
```

It is far from as pretty as it was before we worried about memory management, but it is also not as bad as before we had the variables. Well, not quite. Not far from it, though.

But we only have one place where we need to specify which variables should be freed by the function, and that is the `ENTER()` macro. If we use `RETURN()` or `RETURN_PROTECTED()`, the variables are automatically `decref()`’ed when we return. Yes, we still have to keep track of which variables should be protected, but that is in the same expression, RETURN_PROTECTED, as where we use them, so I tell myself that it will be easier.

The `reverse()` function looks like:

```c
list reverse(list x, list acc)
{
  ENTER(x, acc);
  if (is_nil(x)) {
    RETURN_PROTECTED(acc, acc);
  } else {
    list next = x->next;
    int value = x->value;
    RETURN_PROTECTED(
      reverse(next, cons(value, acc)),
      next, acc
    );
  }
}
```

We still need to get the `next` and `value` from `x` before `RETURN_PROTECTED()`, because we cannot access `x` after we have decremented it, but we are not terribly far from the clean version of the function.

The remaining functions are similar:

```c
list concat(list x, list y)
{
  ENTER(x, y);
  if (is_nil(x)) {
    RETURN_PROTECTED(y, y);
  } else {
    list next = x->next;
    int value = x->value;
    RETURN_PROTECTED(
      cons(value, concat(next, y)),
      next, y
    );
  }
}

list prepend_list(list x, list acc)
{
  ENTER(x, acc);

  if (is_nil(x)) {
    RETURN_PROTECTED(acc, acc);
  } else {
    list next = x->next;
    int value = x->value;
    RETURN_PROTECTED(
      prepend_list(next, cons(value, acc)),
      next, acc
    );
  }
}
list concat_tr(list x, list y, list acc)
{
  ENTER(x, y, acc);
  if (is_nil(x)) {
    RETURN_PROTECTED(
      prepend_list(acc, y),
      acc, y
    );
  } else {
    list next = x->next;
    int value = x->value;
    RETURN_PROTECTED(
      concat_tr(next, y, cons(value, acc)),
      next, y, acc
    );
  }
}
```

They are not pretty, even with the assistance of rather ugly macros, but for memory management like this, it is as good as I can make it for now. We are talking C, after all.

I could make it much prettier if I could analyse and work with expressions given to macros, but that just isn’t possible with cpp. So I don’t get the syntax I would like.


## Efficiency?

There is a lot of increment/decrement going on everywhere now. If we didn’t have to handle errors, we could get rid of many of them. All the input variables that we end up protecting and then unprotecting, we could leave alone if we were sure that we wouldn’t have to bail out with an error. That might be something to look at. But I would rather think if there are other ways to make this smarter. It is the protect/unprotect thing that bothers me. It seems like such a silly way you protect a variable from being garbage collected. I am just not sure there is a smarter way, if, in theory, each of the variables could be deallocated when one of the others are decremented. If we don’t have a counted reference to all the variables, then *any* `decref()` could potentially remove a value we have a pointer to. It isn’t so bad with these lists, but in general, we could. So we probably can’t get around having to increment at the beginning and then decrement when we are done. But I am not sure…

I would love to get comments on this, and suggestions for improvements. But right now, I have to run, because I will get in trouble if I don’t get the Osso Buco for tonight started before long… and I need to get some firework in and the fire started before the missus is home, if I know what’s good for me.

But leave a comment, and I look forward to reading it when I am allowed to play again.


