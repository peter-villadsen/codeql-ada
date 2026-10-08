/**
 * @name Identical operands in boolean expression
 * @description Using the same operand on both sides of a logical operator (`X and X`,
 *              `X or else X`, ...) is always equivalent to just that operand and usually
 *              indicates a typo for a different name.
 * @id ada/identical-operands
 * @kind problem
 * @problem.severity warning
 * @tags correctness
 */

import ada

from BinOp op, Name left, Name right
where
  (
    op.getOp() instanceof OpAnd or
    op.getOp() instanceof OpOr or
    op.getOp() instanceof OpAndThen or
    op.getOp() instanceof OpOrElse or
    op.getOp() instanceof OpXor
  ) and
  left = op.getLeft() and
  right = op.getRight() and
  left.denotesSameEntityAs(right) and
  not left.getAPrimaryQlClass() = "CallExpr" and
  not right.getAPrimaryQlClass() = "CallExpr" and
  not exists(AdaNode c | c.getParent+() = left and c.getAPrimaryQlClass() = "CallExpr") and
  not exists(AdaNode c | c.getParent+() = right and c.getAPrimaryQlClass() = "CallExpr") and
  op.fromSource()
select op, "Both operands of this expression are " + left.getText() + "."
