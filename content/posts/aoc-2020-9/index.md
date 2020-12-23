+++
title = "Advent of Code 2020 — day 22"
date = 2020-12-22T06:51:59+01:00
draft = false
tags = ["python", "programming"]
categories = ["Programming"]
+++


This will be the last post I write before New Year. We have vacation in the house from tomorrow, and I won’t be hacking when I am supposed to be social—I am told. I will do the last three puzzles, and post them, after the holiday.

But it was a nice and easy day today, with one small irritant that took up most of the time I spent on the puzzles. Anyway, to it!

[The task today is to play a game of cards.](https://adventofcode.com/2020/day/22). For Puzzle #1, the description of the game is straightforward, and so is the implementation.

For once, parsing the data is easy:


```python
f = open('/Users/mailund/Projects/adventofcode/2020/22/test.txt')
def parse_player(player):
    return tuple(map(int, player.strip().split('\n')[1:]))
player1, player2 = map(parse_player, f.read().split('\n\n'))
```

I place player hands in a `tuple()`, and that becomes important later!

The way the game is played is well described, and the simplest imaginable implementation will solve the puzzle:


```python
def play(p1, p2):
    while p1 and p2:
        if p1[0] > p2[0]:
            p1 += (p1[0],p2[0])
        else:
            p2 += (p2[0],p1[0])
        p1, p2 = p1[1:], p2[1:]
    return p1 if p1 else p2

result = sum((i+1)*x for i,x in enumerate(reversed(winner)))
print(f"Puzzle #1: {result}")
```

I didn’t use a `tuple()` but a list in my first implementation. That will still work, because the algorithm doesn’t have to leave the function arguments unchanged, and the code works equally well with lists or tuples. But the `+=` operator will modify its left-hand side. In Puzzle #2, I changed the representation to tuples to avoid this problem. But I did not, and that lost me 20-30 minutes, changed the representation in Puzzle #1. So I spent a lot of time debugging Puzzle #2 only to later find out that the issue was the input. I gave Puzzle #2 the input after running Puzzle #1, and by then it was modified.

I fixed the problem by changing from lists to tuples. You can still use `+=`, it just does something else for tuples. For lists, `+=` will in-place modify the left-hand-side. For tuples, `+=`, is syntactic sugar for addition and an assignment, so you are assigning to a variable and not modifying an object. That was frustrating.

Anyway, the solution to Puzzle #2—that was working all along, it just needed the correct input—is not much more complex than Puzzle #1 (although deciphering the game description is).


```python
def play(p1, p2, s1, s2):
    while p1 and p2:
        if p1 in s1 or p2 in s2:
            return 1, p1
        s1.add(p1)
        s2.add(p2)

        card1,card2 = p1[0],p2[0]
        p1, p2 = p1[1:], p2[1:]

        winner = None
        if card1 > len(p1) or card2 > len(p2):
            winner = 1 if card1 > card2 else 2
        else:
            winner,_ = play(p1[:card1], p2[:card2], set(), set())

        if winner == 1:    
            p1 += (card1,card2)
        else:
            p2 += (card2,card1)
        
    return (1,p1) if p1 else (2,p2)

_, winner = play(player1, player2, set())
result = sum((i+1)*x for i,x in enumerate(reversed(winner)))
print(f"Puzzle #2: {result}")
```

If the puzzles over Christmas are equally simple, I could get away with solving them there, and I would give it a try if I were that optimistic. I am not, however. I fear we will run into another Day 20 soon. And I know myself well enough to realise that I will not be able to let a puzzle go, so if I start, I will continue until I am done. It is best to stop now, and return in the New Year. That also gives me something to look forward to.

## Update: A C implementation

Since the puzzles were so simple, I was challenged to implement them in C as well.

{{< tweet 1341267688241422336 >}}


The first puzzle is easy enough, but I needed a set for Puzzle #2, so there was a little more work to that.

We don’t have any built-in data structures in C, so you have to roll your own of everything, but I have a list and a search tree implementation lying around from my upcoming book, and I adapted those.

### A linked list

The linked list is a circular list, where I added an integer to the head, to keep track of the length. We need to know the length for Puzzle #2, to check if we should recurse. I added a function for taking the first link out of a list, for when we need to extract the top card, but otherwise it is all generic stuff.

```c
// Linked list -----------------------------------------
struct link {
  int value;
  struct link *prev;
  struct link *next;
};

struct link *new_link(int val)
{
  struct link *link = malloc(sizeof *link);
  if (!link) abort();
  link->value = val;
  link->prev = link->next = 0;
  return link;
}

static inline
void connect_neighbours(struct link *x)
{ x->next->prev = x; x->prev->next = x; }

static inline
void link_after(struct link *x, struct link *y)
{ y->prev = x; y->next = x->next; connect_neighbours(y); }

static inline
void unlink(struct link *x)
{ x->next->prev = x->prev; x->prev->next = x->next; }



struct list {
    int len;
    struct link head;
};

#define head(x)     (&((x)->head))
#define front(x)    (head(x)->next)
#define back(x)     (head(x)->prev)
#define is_empty(x) ( head(x) == front(x) )
#define length(x)   ((x)->len)

struct list *new_list(void)
{
    struct list *x = malloc(sizeof *x);
    if (!x) abort();
    x->head.next = x->head.prev = &x->head;
    x->len = 0;
    return x;
}

void free_list(struct list *x)
{
    struct link *link = front(x);
    while (link != head(x)) {
        struct link *next = link->next;
        free(link);
        link = next;
    }
    free(x);
}


void append(struct list *x, struct link *link)
{
    link_after(back(x), link);
    x->len++;
}

struct link *pop_front(struct list *x)
{
    assert(!is_empty(x));
    struct link *link = front(x);
    unlink(link); x->len--;
    return link;
}

struct list *make_list(int n, int array[n])
{
    struct list *x = new_list();
    for (int i = 0; i < n; i++) {
        append(x, new_link(array[i]));
    }
    return x;
}

struct list *copy_prefix(struct list *x, int n)
{
    struct list *copy = new_list();
    struct link *link = front(x);
    while (link != head(x) && n) {
        append(copy, new_link(link->value));
        link = link->next;
        n--;
    }
    return copy;
}
#define copy_list(x) copy_prefix(x, length(x))
```


### Binary search tree

For the set in Puzzle #2, I used a binary search tree.

To use a binary search tree, we need an order on the elements, so I needed a comparison on lists. There doesn’t have to be any sensible order on the lists, as long as it is a total order, but it is natural to use lexicographical order. That means that we compare the prefixes on the lists until there is a difference, and then that difference determines which is the smaller. If one list is a prefix of another, then the shorter list is the smaller list as well.

```c
int compare_lists(struct list *x, struct list *y)
{
    struct link *lx = front(x);
    struct link *ly = front(y);
    while (lx != head(x) && ly != head(y)) {
        if (lx->value != ly->value) return lx->value - ly->value;
        lx = lx->next; ly = ly->next;
    }
    // maybe they are equal?
    if (lx == head(x) && ly == head(y)) return 0;
    // One is a prefix of another -- the shorter is the smallest
    return (lx == head(x)) ? -1 : 1;
}
```


I don’t balance it, and I don’t need to delete elements, so it is a particularly simple implementation:

```c
// Search tree -----------------------------------------
struct node {
  struct list *value;
  struct node *left;
  struct node *right;
};

struct node *node(struct list *value, 
                  struct node *left, struct node *right)
{
  struct node *t = malloc(sizeof *t);
  if (!t) abort();
  *t = (struct node){
    .value = copy_list(value), 
    .left = left, .right = right
  };
  return t;
}
#define leaf(V) node(V, 0, 0)

bool contains(struct node *t, struct list *x)
{
  if (!t) return false;
  int cmp = compare_lists(x, t->value);
  if (cmp == 0) return true;
  if (cmp < 0)  return contains(t->left, x);
  else          return contains(t->right, x);
}


struct node *insert_node(struct node *t, struct node *n)
{
  if (!t) return n;
  int cmp = compare_lists(n->value, t->value);
  if (cmp == 0) {
    free(n); // it was already here
  } else if (cmp < 0) {
    t->left = insert_node(t->left, n);
  } else {
    t->right = insert_node(t->right, n);
  }
  return t;
}

struct node *insert(struct node *t, struct list *x)
{
  struct node *n = leaf(x);
  if (!n) return 0;
  return insert_node(t, n);
}

void print_stree(struct node *t)
{
  if (!t) return;
  putchar('(');
    print_stree(t->left);
    putchar(',');putchar('[');
    print_list(t->value);
    putchar(']');putchar(',');
    print_stree(t->right);
  putchar(')');
}

void free_stree(struct node *t)
{
  if (!t) return;
  free_stree(t->left);
  free_stree(t->right);
  free_list(t->value);
  free(t);
}
```

It is not the smartest search tree I have lying around, but it is the simplest, and it suffices for this day’s challenge.

### Solving the puzzles

With the data structures in place, implementing the puzzle solutions is a straightforward translation from the Python solution:

```c
struct list *play(struct list *p1, struct list *p2)
{
    while (!is_empty(p1) && !is_empty(p2)) {
        struct link *card1 = pop_front(p1);
        struct link *card2 = pop_front(p2);
        if (card1->value > card2->value) {
            append(p1, card1); append(p1, card2);
        } else {
            append(p2, card2); append(p2, card1);
        }
    }
    return is_empty(p1) ? p2 : p1;
}

struct game2_res {
    int winner;
    struct list *winner_hand;
};
#define WIN(w,wh) \
    (struct game2_res){ .winner = (w), .winner_hand = (wh) }

struct game2_res play2(struct list *p1, struct list *p2)
                       
{
    struct node *s1 = 0;
    struct node *s2 = 0;
    struct game2_res winner;

    while (!is_empty(p1) && !is_empty(p2)) {
        if (contains(s1, p1) || contains(s2, p2)) {
            winner = WIN(1, p1);
            goto finish;
        }
        s1 = insert(s1, p1);
        s2 = insert(s2, p2);

        struct link *card1 = pop_front(p1);
        struct link *card2 = pop_front(p2);
        int w;
        if (card1->value > length(p1) || card2->value > length(p2)) {
            w = (card1->value > card2->value) ? 1 : 2;
        } else {
            struct game2_res rec_res;
            struct list *p1_copy = copy_prefix(p1, card1->value);
            struct list *p2_copy = copy_prefix(p2, card2->value);
            rec_res = play2(p1_copy, p2_copy);
            w = rec_res.winner;
            free_list(p1_copy);
            free_list(p2_copy);
        }

        if (w == 1) {
            append(p1, card1); append(p1, card2);
        } else {
            append(p2, card2); append(p2, card1);
        }
    }


    winner = is_empty(p1) ? WIN(2,p2) : WIN(1,p1);
finish:
    free_stree(s1);
    free_stree(s2);
    return winner;
}

int hand_score(struct list *hand)
{
    int res = 0;
    int multiple = 1;
    struct link *link = back(hand);
    while (link != head(hand)) {
        res += multiple * link->value;
        multiple += 1;
        link = link->prev;
    }
    return res;
}

void puzzle1(struct list *p1, struct list *p2)
{
    struct list *p1c = copy_list(p1);
    struct list *p2c = copy_list(p2);
    
    struct list *winner = play(p1c, p2c);
    printf("Score: %d\n", hand_score(winner));
    
    free_list(p1c);
    free_list(p2c);
    // winner is a copy of one of them, so it should not
    // be freed.
}

void puzzle2(struct list *p1, struct list *p2)
{
    struct list *p1c = copy_list(p1);
    struct list *p2c = copy_list(p2);
    
    struct game2_res res = play2(p1c, p2c);
    printf("Score: %d\n", hand_score(res.winner_hand));
    
    free_list(p1c);
    free_list(p2c);
}
```


