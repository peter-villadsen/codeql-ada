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

from Raw::BinOp op, Name left, Name right
where
  (
    op.getOp() instanceof Raw::OpAnd or
    op.getOp() instanceof Raw::OpOr or
    op.getOp() instanceof Raw::OpAndThen or
    op.getOp() instanceof Raw::OpOrElse or
    op.getOp() instanceof Raw::OpXor
  ) and
  left = op.getLeft() and
  right = op.getRight() and
  left.denotesSameEntityAs(right) and
  not left.getAPrimaryQlClass() = "CallExpr" and
  not right.getAPrimaryQlClass() = "CallExpr" and
  not exists(Raw::AdaNode c | c.getParent+() = left and c.getAPrimaryQlClass() = "CallExpr") and
  not exists(Raw::AdaNode c | c.getParent+() = right and c.getAPrimaryQlClass() = "CallExpr") and
  op.(AdaNode).fromSource()
select op, "Both operands of this expression are " + left.getText() + "."
