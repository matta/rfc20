+++
title = "Lower bound -vs- find -vs- gcc -vs- clang"
author = ["Matt Armstrong"]
draft = true
+++

```c++
// Node is a binary tree node.  It has the usual left and right links and
// an integral key.
struct Node {
  Node* left = nullptr;
  Node* right = nullptr;
  int key = 0;
};

// LowerBound returns the first node in the tree rooted at "x" whose key is
// not less than "key", or null if there is no such key.
//
// Another way to phrase the same specification: LowerBound returns the
// first node in the tree rooted at "x" whose key is greater than or equal
// to "key".
//
// A key insight is that this algorithm returns the leftmost key in the
// face of duplicates, so the search must always proceed to a leaf of the
// tree.
ATTRIBUTE_NOIPA Node* LowerBound(Node* x, int key) {
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
