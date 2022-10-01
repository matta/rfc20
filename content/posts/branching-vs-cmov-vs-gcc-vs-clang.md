---
title: Branching vs cmov vs gcc vs clang
author: Matt Armstrong
date: 2022-09-30T20:00:13-07:00
draft: false
---

I recently solved a performance riddle with some binary tree code I'm
working on.  For fun I'm writing all sorts of different binary tree
variations.  I'm primarily using gcc, but I occasionally spot check things
using clang.  The relative performance between each implementation was
unexpectedly large.  I was also observing inexplicably good performance
improvements by merely switching to clang.  The improvement switching to
clang was well above anything I was expecting: 20%, 30%, even nearly 50%.
Why would clang be generating code that performed so well compared to gcc?

**TLDR**: branches vs branchless code.  In this project clang often
generates code that uses `cmov` or is otherwise branchless, whereas gcc
generates code that uses branches for the same source.  Across my different
tree implementations, ostensibly similar code can induce gcc to choose
branchless or branched code, resulting in large performance differences.
In the particular cases I'm looking at, branchless is better.

## Example 1: An array by any other name

Consider a node definition:

```c++
struct Node {
    int key;
    Node* left;
    Node* right;
};
```

and a function using it:

```c++ {linenos=table,hl_lines=[4]}
Node* GetInsertEqualPos(Node* x, Node* y, int key) {
    while (x != nullptr) {
        y = x;
        x = (key < x->key) ? x->left : x->right;
    }
    return y;
}
```

This function is finding the correct parent under which to insert a new
node holding a `key`.  In this case both gcc and clang generate a tight
"branchless" loop, which is to say that the conditional assignment on line
4 is performed without an explicit "jump" in code.

The code gcc generates is below.  The tight loop is labeled `.L6`.  The
functions `x` var is in the `rcx` register, `y` in `rax`.  The code loads
`x->right` into `rcx` unconditionally, then uses `cmov` to overwrite that
with `x->left` based on the key comparison.  The only branch the processor
attempts to predict is `jne .L6`, which it will tend to successfully
predict as this code will usually loop multiple times.

```asm {linenos=table,hl_lines=["9-11"]}
GetInsertEqualPos(Node*, Node*, int):
  mov rax, rdi
  test rdi, rdi
  jne .L4
  jmp .L8
.L6:
  mov rax, rcx
.L4:
  mov rcx, QWORD PTR [rax+16]
  cmp edx, DWORD PTR [rax]
  cmovl rcx, QWORD PTR [rax+8]
  test rcx, rcx
  jne .L6
  ret
.L8:
  mov rax, rsi
  ret
```

Clang generates code that is different and perhaps even clever.  The
register assignments change to `x` in `rdi` and `y` is still in `rdx`.  The
counter register, referred to here by its names `ecx` and `cl`, is used as
an index into the `Node` struct, picking either the left or right member
based on the comparison.

```asm  {linenos=table,hl_lines=["7-10"]}
GetInsertEqualPos(Node*, Node*, int):
  mov rax, rsi
  test rdi, rdi
  je .LBB0_3
.LBB0_1:
  mov rax, rdi
  xor ecx, ecx
  cmp dword ptr [rdi], edx
  setle cl
  mov rdi, qword ptr [rdi + 8*rcx + 8]
  test rdi, rdi
  jne .LBB0_1
.LBB0_3:
  ret
```

This code can be seen on [godbolt
here](https://godbolt.org/#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1DIApACYAQuYukl9ZATwDKjdAGFUtAK4sGe1wAyeAyYAHI%2BAEaYxBLSAA6oCoRODB7evnoJSY4CQSHhLFExUraY9jkMQgRMxARpPn5cpeUpVTUEeWGR0bG21bX1GU0K/R3BXYU9UgCUtqhexMjsHCPEXg4A1KEYmBsmAOxWGgCCG2cbwQQbANaYAJ4mAMxHp%2BfbWABUG/RUBE8v5y2Oy%2BxDwwAQf2eJhOBwAIv9ocdEe9MF8AOKYAgASQYSlq2AAjl4xMpEhAUV9VKQgZ8NndqZcbvdpntDojAQB3BB0XYQVQbMBgJ6wjYMLy0WhxAjEFkHAGA853PaPEWqBEnBXnfnCjYQW5Kp5uDaqAC0T2w%2BtljwAYsazY9sD8riA7ebQeDIfKznD2ediJiFgw6eqkft4ScOLNaJwAKy8PwcLSkVCcNzWawbBTzRa7cyPHikAiaSOza4gGNcAB0%2BzMkgAnAA2SQNjR1gAcGn2Uhj%2Bk4kl4LAkGg0pATSZTHF4ChAI6LicjpDgsBgiBQqBYcR5ZAoEDQG63IGACmYcQUCFQBD4dAI0WnEAixdIEWCNTunALe7YggA8gxaG/51ILAWEMYBxEA/B/QcPAADdMGnQDMFUTBkC8G9314S4ykfWg8AiYhXw8LBH2lPBB3nWYqAMI8ADU8EwDlvziRgMJkQQRDEdgSn4QRFBUdRAN0JoDCMFB00sfQ8OnWBmDYEAogYZAEBA4hrlIOCYm4BseGmWZUClFIEJNb8zCnMoUIqFwGHcTwGn8azOgKIpMkSZIBEGRpSCyNyGEc7pimaCzWlGDy9DsIKBDaWo/MmAKRnaULhlGGLnK4WYswWJY9GlTBlh03sODjUdHwnVQ2wbE0mw2YBkGQXVpS8BhrhZCA00saxqVwQgSD2Mx82pDx93oYhevzaZeDnLRdNIBBMCYLAYggUsQEkNtKzMfYYw0R4Y0eOsNC4OszDbGMe2jDh%2B1IQctuKwCJynGdC2LWYl1XPdN2G8hKHeg9kBE4AAH0Gqaq9aBvYg7wfQDn2YYgAI/dcvwIX9/0fYDQPApNIKCuCEKTJCULQvLMMEbDANw/DCJ2EjQXI/KqKYWj6MY5iEwLHjhFEcRuNkPi1EfXQzH0UCxPaiSKekpbkwMgQjJMsyWmcCBXES0hAnGJypi81yKlV7yKhSrXwugyKQtsoZApNypko1/ywrN9JPPi6LbdiiR0uzLKmhy4mo1jeMSs4MqKqqv7QPqtYmpatqrAkjYuqIEa8yaDZBo%2B6JRrMcanoo2ZZvmnopfOy7rpHMdeHu2xHsmktSDLVb1s27bdv2w7jtOgrHgDu7OAm56/Y4UzbvHXuc6m2YNKSZxJCAA%3D%3D%3D).

When originally writing some of the binary tree code I had an idea similar
to what clang is doing above, so my `Node` struct began life with a
`child[2]` array like this:

```c++
struct Node {
    int key;
    Node* child[2];
};
```

And the `GetInsertEqualPos` function was written like this:

```c++
Node* GetInsertEqualPos(Node* x, Node* y, int key) {
    while (x != nullptr) {
        y = x;
        x = x->child[!(key < x->key)];
    }
    return y;
}
```

With this change both gcc and clang generate nearly identical code, similar
to the clang example above, as can be seen on [godbolt
here](https://godbolt.org/#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1DIApACYAQuYukl9ZATwDKjdAGFUtAK4sGEgBykrgAyeAyYAHI%2BAEaYxAGkAA6oCoRODB7evgnJqY4CoeFRLLHxXIF2mA7pQgRMxASZPn7ltpj2%2BQy19QSFkTFxCQp1DU3ZrcM9fcWlAQCUtqhexMjsHMPEXg4A1BEYmNsmAOxWGgCC25fbYQTbANaYAJ4mAMynF1d7WABU2/RUBFe7yuu32v2IeGACEBbxM52OABEgXCziivphfgBxTAEACSDCUDWwAEcvGJlCkIOjfqpSKCfttHnSbvcnnNDicUSCAO4IOgHCCqbZgMCvBHbBheWi0RIEYjs47AkFXR6HF7i1TI87Kq7RVCebZoFiJNXih6q15ubaqAC0r2w5q1Hx1QrFhtQxrVADFrXaXth/rcQL77RCoTClZdEVyrsQccsGIyndH4ecNltbuiAOqEBBnYjEJgWznaq4sx2w0uXbO5/OFx6/WhhO4KEwAVgsZnbSMrqKOPfeaP2OYIeYLRaxOPxhIIJLJtApChHY/rVOHtfHDetdJro7rE8ZpBjOpPp7P5/LbI5ke2vP520FwtF6olUplcoVJedyotL81vdPPUDSNE03XNNUrVte0KxvEFXRfEDvRDf0mwYFt2wsDRu22YMoJQ5tWw7LhuydEEU2/OMCATJNe0RDgFloTg214PwOC0UhUE4NxrGsbYFCWFYDnMF4eFIAhNHohY7hAF4XgAOlkxSlOUgA2fROEkXgWAkDQNFIVj2M4jheAUEA9PEtj6NIOBYCQED%2BTICgIHs%2Bh4mABRmESBQEFQAg%2BDoAg4lMiBogk0hojCepHk4USjTYQQAHkGFoaLLNILAWEMYBxDS/A42qAA3TBTLSzBVCqLxApi3gbnaMKm2iQtiEeDwsDCuU8G0yyFioAx3IANTwTBuQSxJGGqmRBBEMR2CkSb5CUNQwt0Lh9CylAeMsfQ8GiUzYGYNgQFiBhkAQTLiDuUgivibgVJ4OYFlQWV0hKm0ErMEz2iqToXAYdxPGaPQQjCfoSkGVbcjSAQxhaJIUihhhpgGMo2g6GoRkaAHxlR770amEGZnB2wMZhvRJgaJGwbKBZ%2BOWVY9DlTA1nu9SOGY/SwqM1R/BUm0VMkbZgGQZAHzlLw0PZCBuMsaw6VwQgSEOMwRLpDxjQcpWRLmXgLK0B7SAQTAmCweIICkkAzAATjktsXktnmVLbMw7pUo5/Et1nNI5tKjJMsyxIkhYbMQFAPUSBzyEoFzBmQAwjAAfTFtD/NoQLiGC0K0oi5hmomuLGAIJKUrCjKspy9i8txoqSvYsqKqq7gasEOq0oapqWv2dqIS6lneqYAahpGsbWNE/gptEcQ5rHhaVHUNLdDMNajA2mWtoavazY456BFe97PrR5wIFcUnVuBopkb0SHOhPuG8nSSnZlWypqgEbpRix2Hn86N/egJi%2Bn5Jh/MmGMH7gxpgJemq1GbMysoxNmLFOacG5rzfmho47AFFpsCWD5pZWC2tseWRBiCa1WtsNW4dXKazMNrAO3VzYvCOHJLgzt/C6SkBoSQ9sjgqTUnAr2BleC%2B1sP7XWklWYfW9oZTgOtA4LGuqkZwkggA%3D%3D%3D).

At some point I wanted to make the code more readable, so I introduced
helpers and then modified the code to read them:

```c++
struct Node {
    int key;
    Node* child[2];
};

Node* left(Node* x) { return x->child[0]; }
Node* right(Node* x) { return x->child[1]; }

Node* GetInsertEqualPos(Node* x, Node* y, int key) {
    while (x != nullptr) {
        y = x;
        x = (key < x->key) ? left(x) : right(x);
    }
    return y;
}
```

With this, clang generated essentially the same code as it has in every
example so far, but gcc generated yet another variation that used explicit
branches for everything.  This can be seen on [godbolt
here](https://godbolt.org/#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1DIApACYAQuYukl9ZATwDKjdAGFUtAK4sGIABykrgAyeAyYAHI%2BAEaYxCAA7KQADqgKhE4MHt6%2BASlpGQKh4VEssfFJdpgOmUIETMQE2T5%2BgVU1AnUNBMWRMXGJtvWNzbltwz1hfWUDCQCUtqhexMjsHAoExF4OANQRGJg7JglWGgCCO5c7YQQ7ANaYAJ4mAMynF1f7WABUO8gIdHQJgArBYzCCACKvd7HKFvEznBFnMK0KZ7A6/ehUAgQL6YX6qOZHE47YiYAjLBg7VQAWle2H%2BgJBFg0kOhxKh5xRaLxv2IeGACBxvOpROOFlJ5Mp1LpLwZANoQNBXDZbw5SKRIoA4uSAJIMJSNbAARy8YmUaVxGOppHRPx2j1tN3uTzFJyRVx2AHcFYcIKodmAwK8ITsGF5aLRkps3e9PZ7HkcXqHVNCPfHLgGQzsIA9E683DL6XmxS8AGI7LE4wk7ECkgVC/1zNPnT2w9OXMkU4hU57wxEJTlnDgLWicYG8PwcLSkVCcNzWaw7BRLFaHcwvHikAiaEcLO4gYFcAB0CTMkgAnAA2SRXjQX/waBJSYH6TiSXgsCQaDSkKczucOF4BQQF/HdpxHUg4FgGBEBQVAWGSOg4nISg0EQ5D4mABRmGSBQEFQAg%2BDoAg4hAiBol3UhojCBpHk4Ld0LYQQAHkGFoeiINILAWEMYBxC4/AyRqAA3TAQK4zBVGqLxSIY3gbkwMcuNRaJiDojwsCozY8C/CCFioAxsIANTwTAvRY5JGHkmRBBEMR2CkWz5CUNQqN0Lh9D4lBF0sfQ8GiEDYGYNgQFiBh/l44g7lIMT4m4K8eDmBZUGjTIJJpFizGApTqkcZwIFcUY/CvIIGHQXpSnKEAzDMfJ0nyrJPBaPRUgazJKv6eJPPaRquhGZrclK3ragmTqZniWqhm6Yq9A2bpxuqrgFhXZZVj0TZMDWJK3w4Cc/yowDVH8K8aRvHZgGQZAc02LwGDuIkIAXSxrFtXBCBII4zE3W0PAw%2BhiC%2Bzc5l4cCtGS0gEEwJgsHiCB9xASR/GPMwEmBDQXmBF4Lw0LgLzMfxgVfZSP1IL90YOrjAOA0Dt13BZoLg9CkIB1CIGZzCUAMIwAH1bvu4jaFI4hyMoriaOYYhOMYhDmIINiOKoni%2BIEmchLyvAxIkmcpJkuTuAUwQlKo1T1KlzS1hnHS9PBvgjIUUzzMs6yDec%2BzxCc/hBEUFR1C43Q6u54xfJsVSgvh2c0oEDKspy%2BxGpccrZs8kIpiqgZPLawompyPxM4KRrFoz2xco6Bh%2BqaQa85L%2BPRoWtOurmiZk%2Bmxoi%2B6lbV3WzzNu2yDlP2/9eCOk6zskP4g5urZ7se56rD8nZ3qIQGN08nY/pZuIgbMEG6f0hYoZhgYI5Jz9D1/IfZ04GmwPphGkZRtGMaxnG8YJondpeSdDuvvfwdHTg2VKYAV/mDPcsUyKZERkAA),
or below:

```c++
GetInsertEqualPos(Node*, Node*, int):
  mov rax, rdi
  test rdi, rdi
  jne .L5
  jmp .L9
.L11:
  mov rcx, QWORD PTR [rax+8]
  test rcx, rcx
  je .L10
.L7:
  mov rax, rcx
.L5:
  cmp DWORD PTR [rax], edx
  jg .L11
  mov rcx, QWORD PTR [rax+16]
  test rcx, rcx
  jne .L7
.L10:
  ret
.L9:
  mov rax, rsi
  ret
```

And it was this variation that was *abysmally slow*.  Binary trees take the
left or right path nearly randomly.  The processor was unable to
successfully predict them, and so the code pays the cost of a branch
misprediction quite often.  In my benchmarks this penalty amounted to about
a 20-30% performance loss.

I switched back to explicit `Node* left;` and `Node* right;` fields and gcc
now generated branchless code.  Et voilà, my Red-Black tree was now on par
C++'s `std::multimap` when compiled with gcc.

## Example 2: The lower bounds of sadness

This is an example of a function that clang seems to happily compile to
branch free code, but gcc does not.  I can't figure out how to get gcc to
use branch free code, hence the sadness.  This function returns the "lower
bound" for a key, is the first node with a key greater than or equal to a
given key.  The code is quite similar to `GetInsertEqualPos` except that
there is another conditionally assigned variable in the loop.  Using the
same `Node` definition, the code looks like this:

```c++
Node* LowerBound(Node* x, int key) {
  Node* lower = nullptr;
  while (x != nullptr) {
    if (!(x->key < key)) {
      lower = x;
      x = x->left;
    } else {
      x = x->right;
    }
  }
  return lower;
}
```

Now, if we compile [this code with `clang` and `gcc` on
godbolt](https://godbolt.org/#g:!((g:!((g:!((h:codeEditor,i:(filename:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,selection:(endColumn:2,endLineNumber:25,positionColumn:1,positionLineNumber:14,selectionStartColumn:2,selectionStartLineNumber:25,startColumn:1,startLineNumber:14),source:'//+Node+is+a+binary+tree+node.++It+has+the%0A//+usual+left+and+right+links+and+an%0A//+integral+key.%0Astruct+Node+%7B%0A++++Node*+left%3B%0A++++Node*+right%3B%0A++++int+key%3B%0A%7D%3B%0A%0A//+LowerBound+returns+the+first+node+in%0A//+the+tree+rooted+at+%22x%22+whose+key+is%0A//+not+less+than+%22key%22,+or+null+if+there%0A//+is+no+such+key.%0ANode*+LowerBound(Node*+x,+int+key)+%7B%0A++Node*+lower+%3D+nullptr%3B%0A++while+(x+!!%3D+nullptr)+%7B%0A++++if+(!!(x-%3Ekey+%3C+key))+%7B%0A++++++lower+%3D+x%3B%0A++++++x+%3D+x-%3Eleft%3B%0A++++%7D+else+%7B%0A++++++x+%3D+x-%3Eright%3B%0A++++%7D%0A++%7D%0A++return+lower%3B%0A%7D'),l:'5',n:'0',o:'C%2B%2B+source+%231',t:'0')),k:46.74509803921569,l:'4',n:'0',o:'',s:0,t:'0'),(g:!((g:!((h:compiler,i:(compiler:g122,filters:(b:'0',binary:'1',commentOnly:'0',demangle:'0',directives:'0',execute:'1',intel:'0',libraryCode:'0',trim:'1'),flagsViewOpen:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,libs:!((name:benchmark,ver:'161')),options:'-O2+-std%3Dc%2B%2B20',selection:(endColumn:1,endLineNumber:1,positionColumn:1,positionLineNumber:1,selectionStartColumn:1,selectionStartLineNumber:1,startColumn:1,startLineNumber:1),source:1,tree:'1'),l:'5',n:'0',o:'x86-64+gcc+12.2+(C%2B%2B,+Editor+%231,+Compiler+%231)',t:'0')),k:46.855671198782,l:'4',m:45.998383185125306,n:'0',o:'',s:0,t:'0'),(g:!((h:compiler,i:(compiler:clang1500,filters:(b:'0',binary:'1',commentOnly:'0',demangle:'0',directives:'0',execute:'1',intel:'0',libraryCode:'0',trim:'1'),flagsViewOpen:'1',fontScale:14,fontUsePx:'0',j:2,lang:c%2B%2B,libs:!(),options:'-O2+-std%3Dc%2B%2B20',selection:(endColumn:1,endLineNumber:1,positionColumn:1,positionLineNumber:1,selectionStartColumn:1,selectionStartLineNumber:1,startColumn:1,startLineNumber:1),source:1,tree:'1'),l:'5',n:'0',o:'x86-64+clang+15.0.0+(C%2B%2B,+Editor+%231,+Compiler+%232)',t:'0')),header:(),l:'4',m:54.001616814874694,n:'0',o:'',s:0,t:'0')),k:53.25490196078431,l:'3',n:'0',o:'',t:'0')),l:'2',n:'0',o:'',t:'0')),version:4)
we get this for gcc:

```asm  {linenos=table,hl_lines=[10]}
LowerBound(Node*, int):
  xor ecx, ecx
.L8:
  test rdi, rdi
  je .L1
.L10:
  mov rax, QWORD PTR [rdi]    # rax = node->left
  mov rdx, QWORD PTR [rdi+8]  # rdx = node->right
  cmp esi, DWORD PTR [rdi+16] # cmp key and node->key
  jle .L6
  mov rdi, rdx                # x = x->right
  test rdi, rdi
  jne .L10                    # goto .L10 if x != 0
.L1:
  mov rax, rcx
  ret
.L6:
  mov rcx, rdi                # lower = x
  mov rdi, rax                # x = x->left
  jmp .L8
```

Here, gcc is using comparison tests and branches for everything, placing
the code for the `lower = x` branch under the `.L6` label.  The branch that
the CPU simply can't predict reliably is the `jle .L6` on line 10, since
the binary tree search tends to zig zag arbitrarily down the tree.

Clang chooses `cmov` for *both* assignments:

```asm  {linenos=table,hl_lines=[8,9]}
LowerBound(Node*, int):
  xor eax, eax
  test rdi, rdi
  je .LBB0_3
.LBB0_1:
  lea rcx, [rdi + 8]
  cmp dword ptr [rdi + 16], esi
  cmovge rcx, rdi
  cmovge rax, rdi
  mov rdi, qword ptr [rcx]
  test rdi, rdi
  jne .LBB0_1
.LBB0_3:
  ret
```

Like the `GetInsertEqualPos` function, `LowerBound` performs better with
branch free code.  So, let's look at one way to force the issue:

```c++  {linenos=table,hl_lines=[4,5]}
template <typename Integer>
Integer Select(bool condition, Integer a, Integer b) {
  using Unsigned = typename std::make_unsigned<Integer>::type;
  Unsigned mask = condition ? static_cast<Unsigned>(-1) : 0;
  return (mask & a) | (~mask & b);
}

template <typename T>
T* Select(bool condition, T* a, T* b) {
  auto au = reinterpret_cast<std::uintptr_t>(a);
  auto bu = reinterpret_cast<std::uintptr_t>(b);
  auto ru = Select(condition, au, bu);
  return reinterpret_cast<T*>(ru);
}

// LowerBound returns the first node in
// the tree rooted at "x" whose key is
// not less than "key", or null if there
// is no such key.
Node* LowerBound(Node* x, int key) {
  Node* lower = nullptr;
  while (x != nullptr) {
    bool cond = !(x->key < key);
    lower = Select(cond, x, lower);
    x = Select(cond, x->left, x->right);
  }
  return lower;
}
```

What have we done here?  Branch free code using bit hackery.  The
highlighted lines in the first select template contain all the trickery,
but the basic idea is to turn a boolean into a bitmask that is either zero
or all ones, then use the bitmask to choose one of two integers.

Gcc generates branch free code ([godbolt link](https://godbolt.org/#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1DIApACYAQuYukl9ZATwDKjdAGFUtAK4sGIAMwAHKSuADJ4DJgAcj4ARpjEAQBspAAOqAqETgwe3r4BwemZjgLhkTEs8Yn%2BKXaYDtlCBEzEBLk%2BfkG2mPYlDE0tBGXRcQnJts2t7fldCpNDESOVYzUAlLaoXsTI7Bzm/hHI3lgA1Cb%2Bbshz%2BILn2CYaAIL7h8eYZxcEAJ6pmAD6BGITEICjuD2eTwA9JCTlEMO88AoTkwTrEIi0vidAZh3gx4QA6E4nACSBBOCCYSIICEw4OhJy8Ci8YhO9CoZMM6BOxDwwAQZNoEQA1kjOciGHSYRECJhgEDaCchZgvvjwXNiF4HLD4WcAOxWJ5EolwrAAKlZmHZ5wNjyN2rN3N5/Ot4Lt0sVypdTxMuoAIl6IY8ZSxUgYZR83N9fsw2CTBLKEmCnsT48AEichD16gQILFUJ4TmgGPg%2BqQ4zK08RkWWUxX07FVnqbXbGRFgCc5AxMsBIlzzr6TtcQCAWEwlX8vF3eb3zm5awniHdh1Haf5m0bO93eydRwohR8B0WS9kPgAxQfNRzIP6iOazzfTzDoO4QAC0XEbIBOGgDduImAILYGBOCBd33cwkmRRsfTcECAD8wLOMxIIbAMfX9b0nmDUMmHDWcVxjd4ABUk0eIjzUzXpc3zBUjyyAQy3I6sTiYhsm1dI0mC8IhkS8A9uUwaUElSf8CBvSkCFnIcQC8aVUkBAEXyYVZf047jUFRPj%2BwEoTiBEgDxLvC5pNkwR5OIRT/GwXMVLXDiiS4niNX4yjswgOjS14stYi8Wz1yJUSgJ0%2BM9NEwzJIuciXw1PzwXQuKoRhUJUAAdwSCxNmLATAOILssRpE4aGIOYTjxU4IklfL3mxd5iHzGUuVwpCzFUcwzBOFKEAyd4lUxRFKrxAVMAUKkKWAtrerassSFKrxaAVPAqCq/9KsRUqNKZZAEA9FVwRNTBzWStLiAyyd0AgfbzVUMt3V66D9Xs%2B0DtZVL020hg5toczVKJTq6HeCBVBOMAwHez7zPu/y7VRGjCwEPt/AHEHAdfO5eojHbYsNaGiVoV6q201yHHc%2BGy2ul7jqx20cZOIHCazYmjzJ1GrLZAhmbuHk%2BQIKm7Xi7GAoAoK8eOtC/Q4dZaE4ABWXg/A4LRSFQTg3GsaxB02bZ3n2HhSAITQJfWIUQGlyR8UkABOSQgjMDQzDMSRdS4C2zGl/ROEkOWDaVzheAUEAND1g31jgWAYEQFBUBDf6yAoEno/oRJgC4e2%2BDoGVisoWJvbRZhiC%2BThdbQFg2EEAB5BhaALhXeCwUcjHEGvSHwf8GgAN2G73MFUepuN2XWhKlpvBViIF848LBvcBPAWELiW%2BAMYAFAANTwTAUrL6M55kQQRDEdgpB3%2BQlDUb3dC4fRDGMNXLH0PBYn92BCJAeIGC20diCFUgO8Sbgkh4VY6xUDyWyP7Dgr4y7tVfNcfsphLDWFtn7BmfQXDFmmH4C%2BYRFgVCqHoIo9EcieA6HgjIBDhg4LGBfOoDQBADCmEQ/IVDkGNHmOQ0YiQqHzHQXoOYgw2HLA4esBQmsdh6BqnPSWMsvZN2VhwVQgQkiviSJIE4wBkDIBOCnfE7UICq3gbfE4uBCAzR1mWDwCc3pmH8B%2BXg%2Bsa6ANIMbSQgR8S6idpIaW/8XYeI0IEN2Q9PakFntLQO8tFayL9gHIO9jSChwjsXVIMdyCUASTHFABgjAAg1AwL%2BNBaAZ39rmHO6J87b2LqXAgFcq7ezrlfRuisW7ZjwB3MBitu69xlNvQe3sR5jy%2BBPXYitp6z24PPKgi8V5rw3lvUZR897iEPvwQQigVDqCbroMwl8jAoBvjYEej8IBAJAQIMBECoEwMRnAqwlhEHdF6NkVB7gGEYJCMWfhuCL74L6Nwz5pC%2BjvMoXcpptCuHPJ4cwkFfDsHsJ4aCvILzeGtABYIjYWxREX3EaMyRHBZakDCbwWR8jFHKMLBk9sEBASTiFI2XRuyyxGKIATKxF8TjmMSYnJC/gzCrFscHdYNImBYESIc92HBAnBNCd7CJtgol2K0A4px0t8QhM8VwXUFs3HSzMIELgGhpBD38NI8JvtonyuxWYI1BKTVysNt/BImRnCSCAA%3D%3D%3D)):

```asm
LowerBound(Node*, int):
  xor ecx, ecx
  test rdi, rdi
  je .L1
.L3:
  xor eax, eax
  cmp DWORD PTR [rdi+16], esi
  mov rdx, rdi
  mov r8, QWORD PTR [rdi]
  setge al
  xor rdx, rcx
  neg rax
  and rdx, rax
  xor rcx, rdx
  mov rdx, QWORD PTR [rdi+8]
  xor r8, rdx
  mov rdi, rdx
  and rax, r8
  xor rdi, rax
  cmp rdx, rax
  jne .L3
.L1:
  mov rax, rcx
  ret
```

So, I guess that is good?  We'll see soon.  First, the cool part.  Clang
has generated *identical code* for this source, using `cmov`, as it did
with the straightforward source written with `if` statements.  Clang
essentially de-obfuscated the bit twiddling done in the new `Select`
function, figured out its final effect, and rewrite semantically equivalent
code using `cmov`.

```asm
LowerBound(Node*, int): # @LowerBound(Node*, int)
  xor eax, eax
  test rdi, rdi
  je .LBB0_3
.LBB0_1: # =>This Inner Loop Header: Depth=1
  lea rcx, [rdi + 8]
  cmp dword ptr [rdi + 16], esi
  cmovge rax, rdi
  cmovge rcx, rdi
  mov rdi, qword ptr [rcx]
  test rdi, rdi
  jne .LBB0_1
.LBB0_3:
  ret
```

Now, as we saw, gcc didn't do quite as well.  It did generate branch free
code.  How "bad" was the branchy code before, and how "good" is the new
code.  I wrote a benchmark and, well, it depends.  Generally, if the binary
tree fits entirely within the L1 cache the branchy code does better,
presumably because the penalty for branch mispredictions in L1 cache is
fairly low.  Once the tree is larger than the L1 cache, the branch free
code begins to win big.

| Height | Nodes   | Branchy GCC | Branchless Gcc | Change | Notes                   |
|--------|---------|:-----------:|:--------------:|:------:|-------------------------|
| 8      | 255     | 7ns         | 8.3ns          | +18%   |                         |
| 10     | 1023    | 8.5ns       | 11ns           | +33%   | fits in L1 cache        |
| 11     | 2047    | 9ns         | 14ns           | +49%   | 2x bigger than L1 cache |
| 12     | 4095    | 40ns        | 17ns           | -56%   | 4x bigger than L1 cache |
| 14     | 16383   | 60ns        | 28ns           | -54%   | fits in L2 cache        |
| 16     | 65535   | 107ns       | 53ns           | -49%   |                         |
| 18     | 262143  | 114ns       | 60ns           | -47%   |                         |
| 20     | 1048576 | 148ns       | 85ns           | -42%   |                         |

How does this new "Branchless Gcc" approach compare against clang, which
uses `cmov`?  Clang wins in all cases, with gcc being between 35% and 55%
worse.

| Height | Nodes   | Clang  | Branchless Gcc | Change | Notes                   |
|--------|---------|:------:|:--------------:|:------:|-------------------------|
| 8      | 255     | 5ns    | 8.3ns          | +55%   |                         |
| 10     | 1023    | 7ns    | 11ns           | +55%   | fits in L1 cache        |
| 11     | 2047    | 9ns    | 14ns           | +49%   | 2x bigger than L1 cache |
| 12     | 4095    | 11.5ns | 17ns           | +52%   | 4x bigger than L1 cache |
| 14     | 16383   | 20ns   | 28ns           | +44%   | fits in L2 cache        |
| 16     | 65535   | 37ns   | 53ns           | +45%   |                         |
| 18     | 262143  | 42ns   | 60ns           | +41%   |                         |
| 20     | 1048576 | 63ns   | 85ns           | +35%   |                         |


## Lessons

First, don't listen to the internet without thinking.  There are tons of
resources on the internet telling you things like:

 * The compiler is so good at optimization that you should just ignore what
   it does, write simple code, and hope for the best.
 * "Branchless" code is usually worse because it introduces a "data
   dependency" and therefore defeats the processor's ability to execute
   things out of order.  Processors are now quite good at things like out
   of order execution, speculative branch prediction, etc.
 * You'll find people saying that clang is *more* likely to generate code
   with branches, whereas gcc is *more* likely to use `cmov`.

Lies, all lies!  It is *only* through careful benchmarking and performance
analysis that you can really know what is going on with your program.
Learn to effectively use tools like [linux
perf](https://perf.wiki.kernel.org/index.php/Main_Page), `objdump`, and
[godbolt.org](https://godbolt.org/).  Learn to write and run benchmarks
that are unlikely to lie to you.  Doing this is a black art; see LLVM's
[benchmarking tips](https://llvm.org/docs/Benchmarking.html) for just a
taste.

Lies, all lies?  Not really.  What I've stumbled upon here is an edge case,
where code is predictably *not* predictable, which makes the processor's
branch prediction predictably *bad*.  Most branches in most code are fairly
predictable, so the conventional wisdom is actually correct.  What you've
got to watch out for is how to recognize when you've actually got an edge
case on your hands, and what to do about it.

## Further musing

Krister Walfridsson writes about this same issue in his blog post
["Branches/cmov and compiler
optimizations"](https://kristerw.github.io/2022/05/24/branchless/).  He
goes into more detail about the interaction between compiler optimizations
and cmov.  I thought this point of his was particularly interesting:

> Many (most?) cases where GCC incorrectly decides to use a branch instead
> of emitting branchless code comes from optimization passes transforming
> the code to a form where the backend cannot change it to use conditional
> moves.

Check out Linux Torvald's explanation of why `cmov` is "[generally a bad
idea on an aggressively out-of-order
CPU](https://yarchive.net/comp/linux/cmov.html)" ([backup
link](https://groups.google.com/g/fa.linux.kernel/c/KF14avflJ-Q/m/LWChxKApckgJ),
and another [backup
link](https://groups.google.com/search?q=messageid:fa.iHnBwDV8c5pMY8pAiaPKRUcP4QQ@ifi.uio.no&inOrg=false)).
His explanation of why predictable branches can be effectively free is
succinct and clear.

Some search terms that turn up useful related stuff on the web:

 * branchless
 * predicated instruction
 * gcc's command line flags: `-fno-if-conversion` `-fno-if-conversion2`
   `-fno-tree-loop-if-convert` (see
   [docs](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#Optimize-Options)).
