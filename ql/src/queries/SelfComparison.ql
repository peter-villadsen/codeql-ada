/**
 * @name Self-comparison
 * @description Comparing a name to itself (`X = X`, `X <= X`, ...) always yields the
 *              same result regardless of the name's value, and almost always indicates
 *              a typo for a different name or a leftover from earlier editing.
 * @id ada/self-comparison
 * @kind problem
 * @problem.severity warning
 * @tags reliability correctness
 */

import ada

from Raw::RelationOp cmp, Name left, Name right
where
  left = cmp.getLeft() and
  right = cmp.getRight() and
  left.getReferencedDecl() = right.getReferencedDecl()
select cmp,
  "This comparison always yields the same result, since both sides are " + left.getText() + "."
