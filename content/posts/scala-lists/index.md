---
title: "Scala Lists, Eager and Lazy"
date: 2025-02-19T06:22:14+01:00
categories: [Programming]
tags: [Scala, Functional Programming]
---

So, I returned to looking at Scala. I wanted to implement two types of lists: a regular linked list and a lazy list (i.e., a list where you don’t evaluate the tail before you need it). Both are already available in Scala, but I’m solely doing this for educational purposes.

Except for the covariance vs. invariance troubles [I mentioned here](https://mailund.dk/posts/giving-scala-a-go/), there is nothing much to the first variant.

```scala

enum EnumList[+T] extends List[T]:
  case Empty
  case Cons(h: T, t: EnumList[T])

  def isEmpty: Boolean = this match
    case Empty => true
    case _     => false

  def head: T = this match
    case Cons(h, _) => h
    case Empty      => throw new NoSuchElementException("head of empty list")

  def tail: EnumList[T] = this match
    case Cons(_, t) => t
    case Empty => throw new UnsupportedOperationException("tail of empty list")

  def prepend[U >: T](elem: U): EnumList[U] =
    Cons(elem, this)

  def append[U >: T](elem: U): EnumList[U] = this match
    case Empty         => Cons(elem, Empty)
    case Cons(h, tail) => Cons(h, tail.append(elem))

  private def rev[U >: T](acc: EnumList[U]): EnumList[U] = this match
    case Empty         => acc
    case Cons(h, tail) => tail.rev(Cons(h, acc))

  def reverse: EnumList[T] = rev(Empty)
```

Well, I ran into trouble with `reverse` because I tried to define it as

```scala
  val reverse = rev(Empty)
```

thinking `rev` was a curried list, so that should give me a function. It probably does, but I kept getting an exception that  `Empty` wasn’t initialised. If the `EnumList` enum isn’t initialised before the entire body is evaluated, that makes sense. I just didn’t expect it, and I had some trouble working out why the exception was happening.

For lazy lists, I first did a version with a thunk for tail:

```scala
enum LazyList[+T] extends List[T]:
  case Empty
  case Cons(h: T, t: () => LazyList[T])

  def isEmpty = this match
    case Empty => true
    case _     => false

  def head: T = this match
    case Cons(h, _) => h
    case Empty      => throw new NoSuchElementException("head of empty list")

  def tail: LazyList[T] = this match
    case Cons(_, t) => t()
    case Empty => throw new UnsupportedOperationException("tail of empty list")

  def prepend[U >: T](elem: U): LazyList[U] = Cons(elem, () => this)

  def append[U >: T](elem: U): LazyList[U] = this match
    case Empty         => Cons(elem, () => Empty)
    case Cons(h, tail) => Cons(h, () => tail().append(elem))

  def rev[U >: T](acc: LazyList[U]): LazyList[U] = this match
    case Empty      => acc
    case Cons(h, t) => t().rev(Cons(h, () => acc))

  def reverse: LazyList[T] = rev(Empty)
```

The syntax isn’t as pretty as with true lazy evaluation—you have to evaluate the tail to get the value, and you have to put a thunk in the tail of a `Cons`—but it gets the job done, and you can write infinite lists now:

```scala
  // Infinite list of integers starting from n.
  def count(n: Int): LazyList[Int] = Cons(n, () => count(n + 1))

  def take[T](list: LazyList[T], n: Int): LazyList[T] =
    def take_[T](acc: LazyList[T])(list: LazyList[T], n: Int): LazyList[T] =
      (n, list) match
        case (0, _) | (_, Empty) => acc
        case (_, Cons(h, t))     => take_(Cons(h, () => acc))(t(), n - 1)
    take_(Empty)(list, n).reverse
    
  take(count(1), 3) // the list 1, 2, 3
```

For something like an infinite list, this is perfect, but for many persistent data structures, amortisation arguments go out the window with this solution. See e.g. [an example here](https://mailund.dk/posts/lazy-queues/). So I wanted one with memoisation as well.

Scala has a `lazy` keyword and syntax for declaring a parameter call-by-name, but I couldn’t get it to work. For enums and case-classes, it doesn’t seem to be possible to use these features. I have no idea why.

The solution I came up with was wrapping the lazy bit in a separate class—regular classes do allow for call-by-name and memoiased lazy evaluation—and then put that class in the tail part of `Cons`:

```scala
class LazyVal[+T](_value: => T) {
  lazy val value: T = _value
}
enum MemoLazyList[+T] extends List[T]:
  case Empty
  case Cons(h: T, t: LazyVal[MemoLazyList[T]])

  def isEmpty = this match
    case Empty => true
    case _     => false

  def head: T = this match
    case Cons(h, _) => h
    case Empty      => throw new NoSuchElementException("head of empty list")

  def tail: MemoLazyList[T] = this match
    case Cons(_, t) => t.value
    case Empty => throw new UnsupportedOperationException("tail of empty list")

  def prepend[U >: T](elem: U): MemoLazyList[U] = Cons(elem, LazyVal(this))

  def append[U >: T](elem: U): MemoLazyList[U] = this match
    case Empty         => Cons(elem, LazyVal(Empty))
    case Cons(h, tail) => Cons(h, LazyVal(tail.value.append(elem)))

  def rev[U >: T](acc: MemoLazyList[U]): MemoLazyList[U] = this match
    case Empty      => acc
    case Cons(h, t) => t.value.rev(Cons(h, LazyVal(acc)))

  def reverse: MemoLazyList[T] = rev(Empty)
```

I don’t particularly like the boxing and unboxing every time you access the tail of a list, but with the time I had to experiment, it was the best I could come up with.

If you know how to get lazy evaluation directly into the tail of a `Cons` in a way that doesn’t require the wrapping and unwrapping of thunks of the `LazyVal` class, please let me know.


