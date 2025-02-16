---
title: "Giving Scala a Go—Playing with Lists"
date: 2025-02-14T13:19:35+01:00
categories: [Programming]
tags: [programming, Scala]
---

Soon, I will be unemployed — the needs of Kvantify and my interests and qualifications have diverged over the last year — so it is time to brush up on my skills, so I look interesting for potential future employer. Since I don’t know what a future employer will be looking for, this mainly means finding something I’m not familiar with but interested in and playing with it. Today, the choice fell on Scala.

I have had students hand in Scala projects but never programmed in the language myself. I enjoy functional languages, though, so I decided to try it. Did a few smaller exercises and skimmed through a tutorial. 

I learn better when I have something specific I want to achieve, preferably something that I _am_ familiar with, so I don’t need to handle too many new things at once. Since Scala is a functional language, implementing some functional data structures felt like just the thing.

## Lists

There are not many interesting data structures that are simpler than linked lists, and all functional languages have them. Compared to arrays, they are easier to use as building blocks for persistent data structures. Scala already has them, naturally, but I wanted to make my own.

First, I tried to figure out how to define an abstract data structure, and I think the Scala approach is via traits (but please correct me if I am wrong). My idea was to have a function that creates an empty list, then functions for getting the head and tail (ignoring error handling for empty lists here), and for prepending and appending. For linked lists, we usually expect that prepending — i.e., putting a link at the front of a list — is constant time, while appending — creating a new list with the old list’s elements plus a new one at the end — takes linear time.

I quickly wrote some methods but ran into problems when it came to defining a function that returns an empty list. I can’t use a method here because a method requires that I already have a list. Some googling told me that the usual approach then is to put such a method in an object rather than a class and that there is a trick that involves making a “companion” trait for the object. So I came up with this:

```scala
trait List[T] {
  def isEmpty: Boolean
  def head: T
  def tail: List[T]
  def prepend(h: T): List[T]
  def append(t: U): List[T]
  def reverse: List[T]
}

trait ListCompanion[L[_] <: List[?]] {
  def empty[T]: L[T]
}
```

An implementation that just wraps Scala’s own lists could then look like this:

```scala
import _root_.scala.collection.immutable.List as ScalaList

class SimpleList[T](private val elements: ScalaList[T]) extends List[T] {

  override def isEmpty: Boolean = elements.isEmpty

  override def head: T = elements.head
  override def tail: List[T] = new SimpleList[T](elements.tail)
  override def prepend(h: T): List[T] = new SimpleList[T](h :: elements)
  override def append(t: T): List[T] = new SimpleList[T](elements :+ t)
}

object SimpleList extends ListCompanion[SimpleList] {
  override def empty[T]: SimpleList[T] = new SimpleList[T](Nil)
}
```

## Type trouble...

As soon as I tried implementing a version that doesn’t depend on the existing `List`, though, I ran into some trouble. I wanted to implement something like `List[T] = Empty | Cons(T,List[T])` but I couldn’t make `Empty` of type `T` and had to allow a covariant `T`, so I updated the trait to this

```scala
trait List[+T] {
  def isEmpty: Boolean
  def head: T
  def tail: List[T]
  def prepend[U >: T](h: U): List[U]
  def append[U >: T](t: U): List[U]
  def reverse: List[T]
}

trait ListCompanion[L[_] <: List[?]] {
  def empty[T]: L[T]
}
```

I allow `prepend` and `append` to take more general types, and the result of the operation is then a list of the more general type. This also works for union types, so I can, for example, write

```scala
val x = Empty.append(3).append(1.2)
```

and now `x` has type

```scala
val x: LazyList[Int | Double]
```

With that change, I could implement the `List[T]` trait as

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

  val reverse = rev(Empty)

object EnumList extends ListCompanion[EnumList] {
  override def empty[T]: EnumList[T] = Empty
}
```

If you have ever worked with functional languages, there shouldn’t be much difficulty here.

I’m not sure how I feel about this. On the one hand, I like that I can get a list that automatically includes the general type of elements I have added. It is a very flexible way of determining the type and has a “dynamic typing” feel. But that is also what worries me. Sometimes, I really want to ensure that I have a list of exactly the type I asked for when I created the empty list. 

I don’t know how to define the `enum` such that `Empty` has type `EnumList[T]`, which annoys me more than it should. But I don’t have any more time to hammer at it today ‘cause it’s Valentine’s Day and my health, both physically and mentally, depends on me being elsewhere in an hour...


