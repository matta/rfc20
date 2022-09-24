+++
title = "Lower bound -vs- find -vs- gcc -vs- clang"
author = ["Matt Armstrong"]
draft = true
+++

123456789 123456789  123456789  123456789  123456789  123456789  123456789  123456789  123456789
00000000000000000000000000000000000000000000000000000000000000000000000000000000

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id
est laborum.

Consider the following definition of a binary tree node:

```c++
struct Node {
  Node* left = nullptr;
  Node* right = nullptr;
  int key = 0;
};
```

And a `LowerBound` function:

```c++
// LowerBound returns the first node in
// the tree rooted at "x" whose key is
// not less than "key", or null if there
// is no such key.
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

Now, if we compile [this code with `clang` and `gcc` on godbolt](https://godbolt.org/#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1DIApACYAQuYukl9ZATwDKjdAGFUtAK4sGEgOykrgAyeAyYAHI%2BAEaYxCAAzKQADqgKhE4MHt6%2BASlpGQKh4VEssfFJdpgOmUIETMQE2T5%2BXIFVNQJ1DQTFkTFxibb1jc25bcM9faXliQCUtqhexMjsHAD06wDUERiYW3gKW0xb0WENAJ5bBMSY%2Bwx7AHRbWwCSBFsITEcECJgmGgAgpstl4FF4xFt6FQPoZ0FtiHhgAgPrQwgBrI5w44MAHA7ZhAiYYDESHozAXR54hQ3LwOHZ7LYmfxWIEvF67LAAKihmBhTISABEtgwvLRaMkbiYEqzAeyGdyEUiUQLhaLxZLiNLZfLCVtyVdpcKNNq8czBaagXiQcFUAB3OIWJYMeG3AjLBg/P5bGjEGkixlha3bX77G53BGoVBE%2BFMD7mMyqBNbO0INL7A0HBTBgOozAKL2GJlmMwGhOkLYkEVi2gHKjXP63HOHANbcHIBD6ilUoGczA820O4hOrwuiB9nmqCt6g1zJksvEcvY82j2uKq6saqUyxcphB0fYQVRbMBgI2biU3OfMnXsvD1iCno8AWml2Ez0rcXYuc2vC7Z8pQmuxAbkmO4AfKx7nqor4JNg0IEJacrsuaWyYLQSjzrekGgbB2CIsiiHgchLzmruZEAW6HpAUOSHmhwCy0JwACsvB%2BBwWikKgnBuNY1htksKz7OYCQ8KQBCaAxCzoiAkgAGyPP4kjMRoACcAAcGgJKpZhcMxcmqfonCSGxklcZwvAKCAGjiZJCxwLAMCICgqAsMkB5kBQEBoG5HkgMAXAlnwdBEn6lDRGZZzMMQFycGJPlsIIADyDC0LFHG8FgLCGMA4gZaQ%2BC3DUABu%2BZmZgqjVF4RJxbwhLoWZaLRKSMUeFgZk3HgLC1QsVAGMACgAGp4JgdpJckjC1TIggiGI7BSNN8hKGoZm6Fw%2Bg5SgfGWPoeDRFZsDMGwICxAwHbZcQ6KkKV8TcHJPC/lxkqZFZHDPklZhbM%2BNLoEapiWNYZicR0jjOBArhjK0QQutMAzxOtqTpKDWSeC0eiI4UDCw2UgzrSDtQjE0qPjLY6HVMj3SNNjsx44TkN6DSUxhP0OPwwsCiCasejhmsD1GRwrGkOxnHcRwqjqXJz5yZIWzAMgyBbIFjyfRAvEAztWy4IQVYietWweL59Agbrcy8BJGWPTJ8mPOpzH6f4XBcBp/jqWY/MmaQ3XKY8qkaQk6mibbgXMQkGhyULZmi5Z1m2RbpAOc5PnuUb5CUEnfnIAYRh6RoNk0LQoVWRAEX5VFlxTQljAEClaVmVlOV5ZxhXk3gpWvZxFVVTV3B1YIDX5U1LUXG1aycZ13U971/VDSNY0TexYn8DNojiAtS9LSo6j5bobtZ8Y202E1B0QAsqDPQIr3vZ930EL9Qr/VYlhA5ZZOdH44MuvT60hMzMy4/kSNMhfwAZjam/98ZdDpsTKGECGCU16L/OGDMoE5BgYTMBbNFjLC5utHmPV%2BaC2FrwUW4tJbSy2JnHKitmKPA0LQrYqsD4Vi1kQY2ZhRIVgNsndcIkzCm1jloR6fwmBYHiCfd2vBurMUkLQjQXB7pyXUlIdSSkDLSCIeZDg0cbLm0EdJEAIdlbSNUnI1SckNAu0kBwpiHAEimXylHARUl%2BZmHsSLCyTjHo3XSM4SQQA%3D%3D) we get this for `gcc`:

```asm
LowerBound(Node*, int):
  xor ecx, ecx
.L8:
  test rdi, rdi
  je .L1
.L10:
  mov rax, QWORD PTR [rdi]
  mov rdx, QWORD PTR [rdi+8]
  cmp esi, DWORD PTR [rdi+16]
  jle .L6
  mov rdi, rdx
  test rdi, rdi
  jne .L10
.L1:
  mov rax, rcx
  ret
.L6:
  mov rcx, rdi
  mov rdi, rax
  jmp .L8
```

and this for `clang`:

```asm
LowerBound(Node*, int): # @LowerBound(Node*, int)
  xor eax, eax
  test rdi, rdi
  je .LBB0_3
.LBB0_1: # =>This Inner Loop Header: Depth=1
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
