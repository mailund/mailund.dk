---
title: "OOP example in C"
date: 2020-11-12T05:08:49+01:00
draft: false
categories: [Writing, Programming]
tags: [books, writing, programming, C, OOP ,polymorphism]
---

I'm writing the chapter on function pointers in my C pointers book, and I want a nice example of how you can use them to implement rudimentary object-oriented programming with dynamic dispatch.

## Casting and nested structures


The way to do it is simple enough. The C standard guarantees that the first object you put in a `struct` goes at the first memory address of instances of that `struct`, and if you have a pointer to an instance of the `struct`, then you can safely cast it to a pointer to the first element. This means that if you nest `structs`, you can cast your way into the nesting. For example, with:

```c
struct A {
	int a;
};
struct B {
  struct A a;
  int b;
};
struct C {
  struct B b;
  int c;
};
```

you can access members of a `struct C` as if they were members of the nested `struct B` or the nested `struct A` in the `struct B`.

```c
struct C *x = /* some allocation */;
assert(((B*)x)->b == x->b.b);
assert(((A*)x)->a == x->b.a.a);
```

Anywhere you have a function that works with pointers to `struct A` or `struct B`, you can call the function with a pointer to an instance of `struct C`. (They have to be pointers, of course, because otherwise you copy members, and you will only copy members of the type the function expects).

The C standard promises a little more about the memory layout of `struct`s, and you wouldn't have to nest them here. If the `struct`s share a prefix of members, it also works.

```c
struct A {
  int a;
};
struct B {
  int a;
  int b;
};
struct C {
  int a;
  int b;
  int c;
};
```

If you want to use one `struct` as another, though, it is easier to next them.

## Single inheritance objects and classes

We can use this to create classes and objects (or instances) in an object-oriented programming sense. It is close to how C++ was originally implemented. Use nested `structs` for objects, so derived objects contains he data their base cases have, and for virtual functions (or functions with dynamic dispatch, or whatever you want to call them), use nested `structs` for classes.

For polymorphism/dynamic dispatch, have all objects carry a pointer to their class. When we need to call a polymorphic function, we can look up the concrete function in the object's class. We can define a class pointer as `void *`, so it can point to any structure, and define the most basic object as something that has such a pointer. I have also defined a macro, `basetype()` for the casting, just to make it explicit what we are doing. Then I have a macro, `vtbl` that gets the virtual function table, cast to a class type.

```c
typedef void * cls;
typedef struct { cls *cls; } obj;

#define basetype(x, base) ((base *)x)
#define vtbl(inst, base) \
          basetype(((obj *)inst)->cls, base)
```

You can make the `basetype()` more type safe by going into the nested classes rather than casting, but it puts constraints on how the `struct`s must be nested, and if you modify the type hierarchy above a class, you would need to update the code. The cast does what it is supposed to do, if you are careful with it.

Classes must be allocated and initialised before we can use them. There's a function and macro for that:

```c
void *alloc_cls(size_t cls_size,
                void (*cls_init)(cls *))
{
  cls *cls = malloc(cls_size);
  if (!cls) abort(); // error handling
  cls_init(cls);
  return cls;
}

#define INIT_CLS(p, init)                    \
  do {                                       \
    if (!p)                                  \
      p = alloc_cls(                         \
            sizeof *p, (void (*)(cls *))init \
          );                                 \
  } while(0)
```

The `INIT_CLS()` gets a pointer to the class, which I expect is a global variable, initially NULL. If the class hasn't been initialised yet, we allocate it, and use the `init` function provided to initialise it. 

For objects, we can use

```c
void *alloc_obj(size_t obj_size, cls cls)
{
  obj *obj = malloc(obj_size);
  if (!obj) abort(); // error handling
  obj->cls = cls;
  return obj;
}
#define NEW_OBJ(p, cls) alloc_obj(sizeof *p, cls)
```

The `NEW_OBJ()` macro creates an object and sets it class. There is not an initialisation function here, because I expect that initialisers will need arguments, so we cannot handle that generically. The same might be true for classes, but if that day arises, we can deal with it.

## An expression class hierarchy

For a concrete example, we can have generic arithmetic expressions. We can define their main interface as having a `print()` and an `eval()` function. 

```c
typedef struct base_expr *EXP;

// Base class, class definition
typedef struct {
  void   (*print)(EXP);
  double (*eval) (EXP);
} base_expr_cls;
```

The functions are generic, so the implementation dispatch to the table in the class:

```c
void print_expr(EXP e)
{
  vtbl(e, base_expr_cls)->print(e);
}
double eval_expr(EXP e)
{
  return vtbl(e, base_expr_cls)->eval(e);
}
```

When we initialise the class, we don't put any methods in there. They are abstract.

```c
void init_base_expr_cls(base_expr_cls *cls)
{
  cls->print = 0; // abstract method
  cls->eval  = 0; // abstract method
}
```

There is nothing in instances of the base class (except the nested `obj` needed for the class pointer).

```c
// Base class, object definition
typedef struct base_expr {
  obj obj;
} base_expr;

// Base class, methods
void init_base_expr(base_expr *inst)
{
  // nothing to initialise...
}
```


A concrete expression type is one that merely holds a value. It can look like this:

```c
// Value expressions
typedef struct  {
  base_expr_cls base_expr_cls;
} value_expr_cls;
typedef struct {
  base_expr base_expr;
  double value;
} value_expr;

// Concrete class, so must have a struct
value_expr_cls *VALUE_EXPR_CLS = 0; // must be initialised

void value_expr_print(value_expr *val)
{
  printf("%.3f", val->value);
}

double value_expr_eval(value_expr *val)
{
  return val->value;
}

void init_value_expr_cls(value_expr_cls *cls)
{
  init_base_expr_cls(basetype(cls, base_expr_cls));
  basetype(cls, base_expr_cls)->print =
            (void (*)(EXP))value_expr_print;
  basetype(cls, base_expr_cls)->eval  =
            (double (*)(EXP))value_expr_eval;
}

void init_value_expr(value_expr *val, double value)
{
  init_base_expr(basetype(val, base_expr));
  val->value = value;
}

// constructor
EXP value(double value)
{
  INIT_CLS(VALUE_EXPR_CLS, init_value_expr_cls);
  value_expr *val = NEW_OBJ(val, VALUE_EXPR_CLS);
  init_value_expr(val, value);
  return (EXP)val;
}
```

The class holds the base class and nothing else. We are not introducing new virtual functions. The instance structure holds the base class's data and the value. Since it is a concrete class, we need a pointer to hold the class structure. We will initialise it before we create instances. We have an implementation of the two abstract virtual functions; we set them in the class initialisation code, after initialising the base class part. In the object initiations we initialise the base class part and then set the value. For a concrete class we need a constructor, here it is called `value()`, and it initialises the class (if it isn't already there), create a new object with the class, and then initialises object as a value.

In the code below, we define binary expressions and two sub-classes, one for addition and one for subtraction. They follow the pattern we used for the values class.

```c
// Binary expressions
typedef struct {
  base_expr_cls base_expr_cls;
} binary_expr_cls;
typedef struct {
  base_expr base_expr;
  char symb;
  EXP left, right;
} binary_expr;

void print_binary_expr(binary_expr *binop)
{
  putchar('(');
    print_expr(binop->left);
  putchar(')');
  putchar(binop->symb);
  putchar('(');
    print_expr(binop->right);
  putchar(')');
}

void init_binary_expr_cls(binary_expr_cls *cls)
{
  init_base_expr_cls(basetype(cls, base_expr_cls));
  basetype(cls, base_expr_cls)->print =
          (void (*)(EXP))print_binary_expr;
}

void init_binary_expr(binary_expr *binop,
                      char symb, EXP left, EXP right)
{
  init_base_expr(basetype(binop, base_expr));
  binop->symb = symb;
  binop->left = left;
  binop->right = right;
}

// Addition
typedef struct {
  binary_expr_cls binary_expr_cls;
} add_expr_cls;
typedef struct {
  binary_expr binary_expr;
} add_expr;

// Concrete class, so must have a struct
add_expr_cls *ADD_EXPR_CLS = 0; // must be initialised


double eval_add_expr(add_expr *expr)
{
  return eval_expr(basetype(expr, binary_expr)->left) +
         eval_expr(basetype(expr, binary_expr)->right);
}

void init_add_expr_cls(add_expr_cls *cls)
{
  init_binary_expr_cls(basetype(cls, binary_expr_cls));
  basetype(cls, base_expr_cls)->eval =
          (double (*)(EXP))eval_add_expr;
}

void init_add_expr(add_expr *expr, EXP left, EXP right)
{
  init_binary_expr(basetype(expr, binary_expr),
                   '+', left, right);
}

// constructor
EXP add(EXP left, EXP right)
{
  INIT_CLS(ADD_EXPR_CLS, init_add_expr_cls);
  add_expr *expr = NEW_OBJ(expr, ADD_EXPR_CLS);
  init_add_expr(expr, left, right);
  return (EXP)expr;
}


// Subtraction
typedef struct {
  binary_expr_cls binary_expr_cls;
} sub_expr_cls;
typedef struct {
  binary_expr binary_expr;
} sub_expr;

// Concrete class, so must have a struct
sub_expr_cls *SUB_EXPR_CLS = 0; // must be initialised


double eval_sub_expr(sub_expr *expr)
{
  return eval_expr(basetype(expr, binary_expr)->left) -
         eval_expr(basetype(expr, binary_expr)->right);
}

void init_sub_expr_cls(sub_expr_cls *cls)
{
  init_binary_expr_cls(basetype(cls, binary_expr_cls));
  basetype(cls, base_expr_cls)->eval =
          (double (*)(EXP))eval_sub_expr;
}

void init_sub_expr(add_expr *expr, EXP left, EXP right)
{
  init_binary_expr(basetype(expr, binary_expr),
                   '-', left, right);
}

// constructor
EXP sub(EXP left, EXP right)
{
  INIT_CLS(SUB_EXPR_CLS, init_sub_expr_cls);
  add_expr *expr = NEW_OBJ(expr, SUB_EXPR_CLS);
  init_sub_expr(expr, left, right);
  return (EXP)expr;
}
```

You can use the expressions like this:

```c
int main(void)
{
  EXP expr =
    add(value(1.0),
        sub(value(10.0),
            value(2.0))
    );
  print_expr(expr); putchar('\n');
  printf("evaluates to %f\n", eval_expr(expr));

  return 0;
}
```

## A new example?

The expressions example shows most of the ideas with implementing classes in this way, but there is not an example of adding to the interface. The abstract interface, `print()` and `eval()`, is all there is. I would like an example where I also add a virtual method to a subclass. I just cannot think of something that isn't entirely artificial, like "animals are living things but can also move..." or such things. If you have any suggestions, I would love to hear from you.
