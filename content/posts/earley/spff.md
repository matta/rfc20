---
title: "SPFF-Style Parsing From Earley Recognizers"
date: 2022-01-21T00:00:00-00:00
tags: [earley, parsing, spff]
draft: true
---

# TODO

"A reference GLL implementation"
https://dl.acm.org/doi/abs/10.1145/3623476.3623521 or
https://doi.org/10.1145/3623476.3623521

# SPPF-Style Parsing From Earley Recognisers

# Background theory

I found this section easy to understand for the most part.  Of particular
importance are the following definitions:

Derivation tree
: an ordered tree whose root is labelled with the start symbol, leaf nodes
are labeled with a terminal or `None` and interior nodes are labeled with a
non-terminal symbol, and have a sequence of children corresponding to the
symbols on the right hand side of a rule for A.

Shared packed parse forest (SPFF)
: is a representation designed to reduce the space required to represent
multiple derivation trees for an ambiguous sentence. In an SPPF, nodes
which have the same tree below them are shared and nodes which correspond
to different derivations of the same substring from the same non-terminal
are combined by creating a packed node for each family of
children. Examples are given in Sections 3 and 4. Nodes can be packed only
if their yields correspond to the same portion of the input string. Thus,
to make it easier to determine whether two alternates can be packed under a
given node, SPPF nodes are labelled with a triple (x, j, i) where
a<sub>j</sub>+1 . . . a<sub>i</sub> is a substring matched by x. To obtain
a cubic algorithm we use binarised SPPFs which contain intermediate
additional nodes but which are of worst case cubic size. (The SPPF is said
to be binarised because the additional nodes ensure that nodes whose
children are not packed nodes have out-degree at most two.)


# A cubic parser which walks the Earley sets

In this section the paper describes an approach to producing SPFF directly
from the Earley sets produced by an Early recognizer.

With the goal of making the paper more accessible to non-academics, who are
less used to reading mathematical notation and more used to reading plain
text, I have made the following changes to the notation and format used in
the academic paper:

1. α and α′ is replaced by `ALPHA`.
1. β is replaced by `BETA`.
1. Change "a" to "c" when "a" referenced a terminal.
1. ε is replaced by `None`.
1. ≠ is replaced by `!=`.
1. ∈ is replaced by "is in the set"
1. <b>E</b><sub>i</sub> is written `E[i]`.
1. Place braces in idiomatic places.



```
Buildtree(u, p) {
  suppose that p is in the set E[i]
    and that p is of the form (A ::= ALPHA · BETA, j)
  mark p as processed

  if p = (A ::= ·, j) {
    if there is no SPPF node v labeled (A, i, i) {
      create one with child node None
    }
    if u does not have a family (v) then add the family (v) to u
  }

  if p = (A ::= c · BETA, j) (where c is a terminal) {
    if there is no SPPF node v labeled (c, i − 1, i) create one
    if u does not have a family (v) then add the family (v) to u
  }

  if p = (A ::= C · BETA, j) (where C is a non-terminal) {
    if there is no SPPF node v labeled (C, j, i) create one
    if u does not have a family (v) then add the family (v) to u
    for each reduction pointer from p labeled j {
      suppose that the pointer points to q
      if q is not marked as processed Buildtree(v, q)
    }
  }

  if p = (A ::= ALPHA c · BETA, j) (where c is a terminal, ALPHA != None) {
    if there is no SPPF node v labeled (c, i − 1, i) create one
    if there is no SPPF node w labeled (A ::= ALPHA · c BETA, j, i − 1) create one
    for each target p′ of a predecessor pointer labeled i − 1 from p {
      if p′ is not marked as processed Buildtree(w, p′)
    }
    if u does not have a family (w, v) add the family (w, v) to u
  }

  if p = (A ::= ALPHA C · BETA, j) (where C is a non-terminal, ALPHA != None) {
    for each reduction pointer from p {
      suppose that the pointer is labeled l and points to q
      if there is no SPPF node v labeled (C, l, i) create one
      if q is not marked as processed Buildtree(v, q)
      if there is no SPPF node w labeled (A ::= ALPHA x · C BETA, j, l) create one
      for each target p′ of a predecessor pointer labeled l from p {
        if p′ is not marked as processed Buildtree(w, p′) }
      if u does not have a family (w, v) add the family (w, v) to u
    }
  }
}

PARSER {
  create an SPPF node u labeled (S, 0, n)
  for each decorated item p = (S ::= ALPHA ·, 0) is in the set E[n] {
    Buildtree(u, p)
  }
}
```
