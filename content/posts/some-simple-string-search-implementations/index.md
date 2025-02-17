---
title: "Simple String Search Implementations"
date: 2025-02-16T06:39:39+01:00
categories: [Programming, Algorithms]
tags: [C, Rust, Go, Python]
---

I’ll get back to playing with Scala soon, but since I don’t know which skills to brush up on, I also decided to play with a few other things.

I have taught string algorithms for over a decade, so I figured that using a few simple algorithms I know very well would be an interesting way to play with how the same goal can be achieved in different languages.

You can usually translate a solution from one language into an almost duplicate in another (with a few exceptions, such as when you have to use immutable data structures)—and I have seen a lot of solutions that gave me that vibe—but languages have idioms. Sometimes, such a solution _feels_ wrong in the new language. They clash with what you would expect if you were familiar with the second language. They are not ergonomic to use in the new language because they don’t fit in with the ecosystem.

So, it can be interesting to take the same algorithm and try it out in different languages, adapt the implementation to what feels natural there, and see how implementations differ.

I picked a couple of string algorithms and implemented them in two languages I have used since the 1990s (Python and C) and two languages I have used in projects before, but where I feel that I still have much to learn (Go and Rust).

## A naïve search algorithm

Given two strings, `x` and `p`, find all occurrences of `p` in `x` and return their indices.

The most straightforward, most naïve approach is to position `p` at every index in `x` and see if the location matches. Comparing `p` against a location in `x` takes time _m_ if _m_ is the length of `p`, so if `x`’s length is _n_, so we do _n-m_ comparisons, the worst-case total running time is _O(nm)_.

In practice, checking one location is faster than _m_ since we don’t continue comparing past a mismatch. If the expected time to a mismatch is a constant, it would be if we use random strings, then the expected running time is _O(n)_. So “naïve” doesn’t mean stupid. But it _is_ simple.

### Python

In Python, you would expect to iterate through matches with a `for` loop:

```python
for match in naive(x, p):
   ...
```

So, a solution should return an iterator. Luckily, we have the `yield` keyword to turn a function into a generator, so this is straightforward:

```python
def naive(x: str, p: str) -> Iterator[int]:
    if len(x) == 0 or len(p) == 0: return
    for i in range(len(x) - len(p) + 1):
        if x[i : i + len(p)] == p:
            yield i
```

A simple implementation of a simple algorithm. It is also reasonably efficient (in the context of Python). Compared to everything else, there isn’t much overhead to using generators.

The early return when `x` and `p` are empty is not strictly necessary, nor is it necessarily giving us the correct answer. If `p` is empty but `x` isn’t, you could argue that the empty string is found between every letter in `x`. But I made a choice, and I stand by it. Dealing with empty strings is a nightmare in string algorithms, as many algorithms’ “natural” implementations will treat them differently (often with crashing, which is clearly wrong). I don’t want to deal with them here, as that is not the point of this post.

### C

You would also expect to use a `for` loop for something like this in C, but `for` loops in C are very different from those in Python. If we use a `for` loop in C, we have three components to work with: the initialisation, the test, and the increment.

```c
for (init; test; increment) {
   ...
}
```

We don’t have co-routines or generators or iterators to hold state; if we need that, we must implement it ourselves.

Luckily, for this algorithm, we can use pointers into `x` as a form of iterator. If `init` finds the first occurrence and `increment` moves to the next, then we have to return a pointer where we can recognise the end of the file. We could use a `NULL` pointer (as I will), or we could point at the end of `x` and make the test a check for whether the pointer points to the zero terminal character, `'\0'`.

I went for a solution that looks like this:

```c
for (const char *i = naive(x, p); i; i = naive(i + 1, p)) {
  ...
}
```

The `naive` function returns a pointer that points at the first occurrence into its input that matches `p` or `NULL` if there are no occurrences. That means we can test for `NULL` (the test `i`) to see if we should enter the body, and if we want to move forward, we call with `i+1` to find the next occurrence (if any).

An implementation could look like this:

```c
const char *naive(const char *x, const char *p) {
  for (const char *i = x; *i != '\0'; i++) {
    for (const char *j = p; /* check in body */; i++, j++)
      if (*j == '\0') // We reached the end of p
        return x;
      else if (*i != *j) // We hit a mismatch
        break;
  }
  return NULL;
}
```

It is more verbose than the Python version, but not by much.

We scan through `x` until the end. We don’t use the length of the input strings because we don’t have those readily available in C, so we use the `'\0'` sentinel instead. For every position in `x`, `i`, we scan through `p`, using `j`. Here, I don’t check for termination in the inner loop because I do it in the first `if` statement, but notice that the inner loop increments both `i` and `j`.

You can implement variations on this, but they will all look roughly like this. There aren’t enough language features to go crazy.

### Go

With Go, I tried a few things. If I wanted to use a loop similar to Python and C, I would need a `for match := range ...`, but `range` is (as far as I can tell) restricted to array, slice, string, map or a channel. So, I have the choice of computing all matches eagerly and returning an array of them (which works fine but is memory inefficient) or using a channel.

I tried using a channel, and it was _SLOW_. This is not surprising, considering that they have to deal with concurrency and synchronisation. I’m not complaining about channels being slow for something they are not intended to be used for. That is fair, but it shoots the idea of using this kind of `for` loop down.

I then tried to build an explicit iterator—the design pattern for when a language doesn’t support it—but I found it an ugly solution. It didn’t feel right for the language. (Of course, I don’t have a strong sense of how Go is supposed to feel, but it still felt off.)

Go, however, has very efficient closures, and those closures are used all over the standard library, so instead of trying to shoehorn an iterator into a language that seems to prefer closures, I also went with using a closure.

Well, I went with the closure _and_ the array solution, because the array solution was a lot easier to test. The function below translates from the closure solution to a function that gives you an array of matches

```go
// Interface with a closure
type callbackSearch = func(x, p string, callback func(int))
// Interface with returning an array
type searchFunc = func(x, p string) []int

func convertSearchAlgo(algo callbackSearch) searchFunc {
	return func(x, p string) []int {
		res := []int{}

		// This will call the closure on every match of p in x
		algo(x, p, func(i int) {
			res = append(res, i)
		})

		// Returning the (sorted) hits
		sort.Ints(res)
		return res
	}
}
```

The `convertSearchAlgo` function also demonstrates how you would use the callback version of the search. Here, the callback is used to get all the matches and append them to an array.

The search implementation is closer to the Python version than the C version; we just use the callback instead of `yield`:

```go
func Naive(x, p string, callback func(int)) {
	n, m := len(x), len(p)
	if n == 0 || m == 0 {
		return
	}
	for i := 0; i < n-m+1; i++ {
		if x[i : i+m] == p {
			callback(i)
		}
	}
}
```

There is another issue that bothered me with the Go implementation and should have bothered me in Python. Not in C, though; C is too primitive even to have an issue with this. What are the strings we are manipulating, and is this a valid way of comparing them?

In the Good Old Days(tm), strings were sequences of ASCII characters. 7-bit words (although usually represented in 8-bit bytes). That is no longer the world we live in.

The day’s standard is Unicode, but representing strings as sequences of simple computer words poses a problem. There are currently 154 998 characters, and expect more to be added. The classical representation of strings as sequences of small computer words hinges on having small alphabets, but that is no longer what we have. So instead, we have to deal with encodings. 

We also have to worry that the exact same string can be written in different ways—beyond just having different encodings—but I’m not going there today!

In Python, strings are represented as sequences of Unicode characters. It works because it chooses the size of its alphabet depending on the letters in a given string. So, we can safely index into a string and get the Unicode character out, and (ignoring the issue I didn’t want to talk about today) we can compare strings by comparing character by character.

There is an issue with how much memory we use to represent strings—we can end up using four bytes per character in a string—and that is a potential problem, but from where we are in this post, it is not something to worry about.

In any language that supports Unicode strings, though, we need to worry at least a little bit, and I did with the Go solution. I wasn’t sure how Go represented strings, so I need to figure that out.

You can run into two problems if a language represents strings with a variable-length encoding such as UTF-8 (which Go uses). With such encodings, the different letters in a string are not sitting at fixed offsets from the beginning of the string, so you cannot index into them the way you would with an array. With an array, `a[i]` is whatever is at the address `a + i * element_size`, but if `element_size` isn’t a constant, you have to scan from the beginning of the string (in the worst case) until you have scanned past `i - 1` other characters. Indexing, then, is not a constant time operation but a linear time one, which would be bad.

Luckily, such languages usually don’t let you index into strings either, so you don’t accidentally write highly inefficient code. But since I _can_ index into Go strings, I have to worry.

If you want to get _characters_ out of a string, Go has glyphs, which are the real Unicode characters. When you index into a `string`, however, you get the individual bytes in the UTF-8 encoding. This means that when I am comparing `x` against `p` in the implementation, I am comparing bytes in the encoding rather than the characters.

The good news is that any occurrence of `p` in `x` would still be found (assuming that encodings were unique, which... well, see above; and they can be put in a canonical form, so...).

The worry then is if I can find an occurrence of the bytes in `p` inside the bytes of `x` that doesn’t match the characters if the bytes start _inside_ a character. However, the UTF-8 encoding is constructed such that this cannot occur. So we are good.

That being said, my go-to solution is to handle characters myself. Build an alphabet and map the strings I work with to that alphabet. This is the most efficient way for many data structures, especially if you work in bioinformatics, where the real alphabets are much smaller than for human languages.

I’m not going to with this Go implementation, though. We are just playing, and I will have to do it in the Rust solution below in any case (because Rust won’t let me index into strings for the reasons just described).

### Rust

In Rust, if you have a `x: str`, you cannot index for a single character, `x[i]`. You _can_ get a slice out, `x[i..i+1]`, but this is a worst-case _O(n)_ operation.

If you are working with small strings, you can get a vector of `char` out of a string (similar to how you can get glyphs out of a Go string), and you can index into a `Vec<char>` in constant time. The `char`, however, is 4 bytes, which is too large for many applications. So here, I took the effort of building my own alphabet and character mapping, so I could reduce strings to arrays using 8 or 16 bits per character.

(You can go lower, but there is only so much I am willing to do for a play example).

I build a table of all the characters I have in a string, and map them to integers. (I leave zero for other uses, although I don’t need it here. It is always good to have a sentinel tucked aside for a rainy day).

```rust
pub struct Alphabet {
    /// A vector of characters storing the alphabet in a specific order.
    chars: Vec<char>,
    /// A hash map mapping each character to its index in the `chars` vector.
    indices: HashMap<char, usize>,
}
```

Then, I have code for creating alphabets (the `from_str` is the most interesting, as it lets me define an alphabet from a string over that alphabet), and I have functions that can translate strings into character vectors.

```rust
impl Alphabet {
    pub fn new(chars: &[char]) -> Alphabet {
        // Turn the chars into the unique chars they contain.
        let mut seen = HashSet::new();
        let mut chars: Vec<char> = chars.iter().cloned().filter(|c| seen.insert(*c)).collect();
        chars.sort_unstable();

        let mut indices = HashMap::with_capacity(chars.len());
        for (i, &c) in chars.iter().enumerate() {
            indices.insert(c, i + 1); // The +1 is to leave room for the sentinel at zero
        }

        Alphabet { chars, indices }
    }

    pub fn from_str(s: &str) -> Alphabet {
        let chars: Vec<char> = s.chars().collect();
        Alphabet::new(&chars)
    }
    pub fn contains(&self, c: char) -> bool {
        self.indices.contains_key(&c)
    }
    pub fn index(&self, c: char) -> Option<usize> {
        self.indices.get(&c).copied()
    }
    pub fn len(&self) -> usize {
        self.chars.len()
    }

    pub fn char_size(&self) -> Result<CharSize, Box<dyn std::error::Error>> {
        CharSize::from_alphabet_size(self.len())
    }

    pub fn map_char<Char>(&self, c: char) -> Result<Char, Box<dyn std::error::Error>>
    where
        Char: CharacterTrait,
    {
        if self.len() > Char::MAX {
            return Err("Alphabet too large for Char type".into());
        }

        let idx = match self.index(c) {
            None => return Err("Character not in alphabet".into()),
            Some(idx) => idx,
        };

        Char::try_from(idx).map_err(|_| "Index conversion failed".into())
    }

    pub fn map_str<Char>(&self, s: &str) -> Result<Vec<Char>, Box<dyn std::error::Error>>
    where
        Char: CharacterTrait,
    {
        s.chars().map(|c| self.map_char(c)).collect()
    }
}
```

I’ve left out some details about character traits and such, but you should get the idea.

The `char_size` gives me an enum I can use to work out the necessary character size for an alphabet. I imagine this won’t be necessary in most applications if you know your strings, but it gives me a way to dispatch to generic functions as well.

```rust
pub enum CharSize {
    /// 8 bits needed for each character
    U8,
    /// 16 bits needed for each character
    U16,
}

impl CharSize {
    pub fn from_alphabet_size(size: usize) -> Result<Self, Box<dyn std::error::Error>> {
        const U8_MAX: usize = <u8 as CharacterTrait>::MAX;
        const U16_MIN: usize = U8_MAX + 1;
        const U16_MAX: usize = <u16 as CharacterTrait>::MAX;
        match size {
            0..=U8_MAX => Ok(CharSize::U8),
            U16_MIN..U16_MAX => Ok(CharSize::U16),
            _ => Err("Alphabet too large for known Char types".into()),
        }
    }
}
```

From this, I made functions to map `str` to my own type, `Str<Char>`, where I know the character size and thus can index into them.

```rust
// StrMappers for dynamic dispatch from alphabets to mappers
pub enum StrMappers {
    /// Mapping to u8 characters
    U8Mapper(StrMapper<u8>),
    /// Mapping to u16 characters
    U16Mapper(StrMapper<u16>),
}

impl StrMappers {
    pub fn new(alphabet: &Rc<Alphabet>) -> Self {
        use CharSize::*;
        use StrMappers::*;
        match alphabet.char_size().unwrap() {
            U8 => U8Mapper(StrMapper::new(alphabet)),
            U16 => U16Mapper(StrMapper::new(alphabet)),
        }
    }

    pub fn new_from_str(s: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let alphabet = Rc::new(Alphabet::from_str(s));
        Ok(Self::new(&alphabet))
    }
}

// Concrete mappers that know the character size
pub struct StrMapper<Char>
where
    Char: CharacterTrait,
{
    /// The alphabet used for character encoding.
    pub alphabet: Rc<Alphabet>,
    _phantom: std::marker::PhantomData<Char>,
}

impl<Char> StrMapper<Char>
where
    Char: CharacterTrait,
{
    pub(self) fn new(alphabet: &Rc<Alphabet>) -> Self {
        Self {
            alphabet: alphabet.clone(),
            _phantom: std::marker::PhantomData,
        }
    }

    pub fn map_str(&self, s: &str) -> Result<Str<Char>, Box<dyn std::error::Error>> {
        let char_vector = self.alphabet.map_str::<Char>(s)?;
        Ok(Str::new(char_vector, &self.alphabet))
    }
}

// Strings with known character size
pub struct Str<Char: CharacterTrait> {
    char_vector: Vec<Char>,
    pub alphabet: Rc<Alphabet>,
}

impl<Char: CharacterTrait> Str<Char> {
    pub fn new(x: Vec<Char>, alphabet: &Rc<Alphabet>) -> Self {
        Self {
            char_vector: x,
            alphabet: alphabet.clone(),
        }
    }

    pub fn from_str(s: &str, alphabet: &Rc<Alphabet>) -> Result<Self, Box<dyn std::error::Error>> {
        if alphabet.len() > Char::MAX {
            return Err("Alphabet too large for Char type".into());
        }

        let x = s
            .chars()
            .map(|c| alphabet.map_char(c))
            .collect::<Result<Vec<Char>, Box<dyn std::error::Error>>>()?;

        Ok(Self::new(x, &alphabet))
    }

    pub fn len(&self) -> usize {
        self.char_vector.len()
    }

    pub fn iter(&self) -> std::slice::Iter<Char> {
        self.char_vector.iter()
    }
}

impl<Char: CharacterTrait> std::ops::Index<usize> for Str<Char>
where
    Char: TryFrom<usize> + Copy,
    <Char as TryFrom<usize>>::Error: std::fmt::Debug,
{
    type Output = Char;

    fn index(&self, index: usize) -> &Self::Output {
        &self.char_vector[index]
    }
}

impl<Char: CharacterTrait> std::ops::IndexMut<usize> for Str<Char>
where
    Char: TryFrom<usize> + Copy,
    <Char as TryFrom<usize>>::Error: std::fmt::Debug,
{
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.char_vector[index]
    }
}
```

It’s a lot of work just to get started, and I feel like I should just have gone with `Vec<char>` at this point...

Anyway, on to the search algorithm. I wanted a version that felt natural to Rust, so I wanted an iterator. I can imagine using the search something like this:

```rust
let result: Vec<usize> = naive(x, p).collect()
```

You can implement this algorithm as an iteration through `x` with a filter on that iterator, but it is hard to read, so I went with explicitly implementing an iterator myself.

First, I tried with the signature

```rust
pub fn naive(x: &str, p: &str) -> impl Iterator<Item = usize> 
```

but during the implementation, it gave me trouble. The `impl Iterator<>` wants a specific (although not specified) implementation of an iterator, one the compiler knows when it emits code, and for early leaving when `x` or `p` were empty, I ended up using `std::iter::empty`. That means that I can return more than one type of iterators, so I used

```rust
pub fn naive(x: &str, p: &str) -> Box<dyn Iterator<Item = usize>> 
```

instead.

I could have used `Either` or something like that as well, but I don’t mind a heap allocation once per search, so this will do.

With the alphabet I have painstakingly implemented, I need to dispatch to concrete vector implementations based on the alphabet size of my strings, so my `naive` does just that:

```rust
pub fn naive(x: &str, p: &str) -> Box<dyn Iterator<Item = usize>> {
    if x.is_empty() || p.is_empty() {
        return Box::new(std::iter::empty());
    }
    if x.len() < p.len() {
        return Box::new(std::iter::empty());
    }

    // We unwrap because we don't expect an alphabet larger than u16
    let mapper = StrMappers::new_from_str(x).unwrap(); 
    match mapper {
        StrMappers::U8Mapper(mapper) => naive_impl(x, p, mapper),
        StrMappers::U16Mapper(mapper) => naive_impl(x, p, mapper),
    }
}
```

The `naive_impl` function then translates the `str` to `Str<Char>` and returns the iterator:

```rust
fn naive_impl<Char>(x: &str, p: &str, mapper: StrMapper<Char>) -> Box<dyn Iterator<Item = usize>>
where
    Char: CharacterTrait,
{
    let x = mapper.map_str(x).unwrap();
    let p = match mapper.map_str(p) {
        Ok(p) => p,
        // If we cannot map p, we also cannot match it
        Err(_) => return Box::new(std::iter::empty()),
    };

    Box::new(NaiveSearch { x, p, i: 0 })
}
```

The iterator, that does the actual work, is the simplest of the code:

```rust

struct NaiveSearch<Char: CharacterTrait> {
    x: Str<Char>,
    p: Str<Char>,
    i: usize,
}

impl<Char: CharacterTrait> Iterator for NaiveSearch<Char> {
    type Item = usize;

    fn next(&mut self) -> Option<Self::Item> {
        let NaiveSearch { x, p, i } = self;
        let n = x.len();
        let m = p.len();
        while *i <= n - m {
            let mut k = 0;
            while k < m && p[k] == x[*i + k] {
                k += 1;
            }
            *i += 1;
            if k == m {
                return Some(*i - 1);
            }
        }
        None
    }
}
```

This ended up being very verbose and much worse than any of the previous languages. This surprises me a bit, and I suspect that my lack of Rust skills is partially to blame. To be fair, though, the code also handles a much harder problem: encoding strings into smaller alphabets.

Still, there is room for improvement in my Rust solution. I would be thrilled to get some pointers.

One approach to make the algorithm itself cleaner is to implement range indexing in `Str<Char>`. It is a _lot_ of boiler plate code, but it simplifies the `next` function to this:

```rust
    fn next(&mut self) -> Option<Self::Item> {
        let NaiveSearch { x, p, i } = self;
        let n = x.len();
        let m = p.len();
        for j in *i..=(n - m) {
            if &x[j..(j + m)] == &p[..] {
                *i = j + 1;
                return Some(j);
            }
        }
        None
    }
```

You pay for the cleaner code here with the boilerplate code elsewhere, but it would be worth it in a more extensive library.

You _can_ also go the callback route I did with Go. I’m not sure how well it fits into Rust’s idioms—I feel that iterators is the right way to go rather than mapping functions—but you get rid of the iterator boilerplate.

```rust
pub fn naive_cb(x: &str, p: &str, cb: &mut dyn FnMut(usize)) {
    if x.is_empty() || p.is_empty() || x.len() < p.len() {
        return;
    }

    // We unwrap because we don't expect alphabet larger than u16
    let mapper = StrMappers::new_from_str(x).unwrap();
    match mapper {
        StrMappers::U8Mapper(mapper) => naive_cb_impl(x, p, mapper, cb),
        StrMappers::U16Mapper(mapper) => naive_cb_impl(x, p, mapper, cb),
    }
}

fn naive_cb_impl<Char>(x: &str, p: &str, mapper: StrMapper<Char>, cb: &mut dyn FnMut(usize))
where
    Char: CharacterTrait,
{
    let x = mapper.map_str(x).unwrap();
    let p = match mapper.map_str(p) {
        Ok(p) => p,
        Err(_) => return,
    };

    let n = x.len();
    let m = p.len();
    for i in 0..=(n - m) {
        if &x[i..(i + m)] == &p[..] {
            cb(i);
        }
    }
}
```

From the callback version I can get an iterator, the same way I could in Go, by collecting all the hits and returning an array.

```rust
pub fn naive_iter(x: &str, p: &str) -> impl Iterator<Item = usize> {
    let mut results = Vec::new();
    naive_cb(x, p, &mut |pos| {
        results.push(pos);
    });
    results.into_iter()
}
```

But just as for Go, I don’t think this feels right. You might search in a ginormous string and terminate after three matches, but with this solution, you would still pay for all the matches in the entire string.

I feel that the iterator solution is the right one; it just feels unnecessarily complicated to write.

----


For my next trick, I will implement the Knuth-Morris-Pratt and Boyer-Moore-Horshpool algorithms. Complexity-wise, it is not that different from the naïve solution, but there are some issues I am looking forward to exploring. I cannot use the simple “pointer as an iterator” trick I used in C because I need to allocate a border-array/jump-table and the character. The BMH base-case complexity of _O(n/m+m)_ needs a little slight-of-hand, as translating the strings will take _O(n+m)_, eliminating one of the main benefits of that algorithm. But we will see how it goes when I have time to attack it.

For now, I have to figure out how to write a CV and get that done. If I don’t, I will suddenly find myself with way too much time to play with programming.

