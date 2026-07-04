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

// Limitation (see DECISIONS.md D-015): `ada_xref` is only emitted when the referenced
// declaration is in the analyzed source set, so identical operands naming an entity
// declared in an unanalyzed library unit (e.g. `Lib.X and Lib.X`) are not detected.
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
  left.getReferencedDecl() = right.getReferencedDecl() and
  not left.getAPrimaryQlClass() = "CallExpr" and
  not right.getAPrimaryQlClass() = "CallExpr" and
  not exists(Raw::AdaNode c | c.getParent+() = left and c.getAPrimaryQlClass() = "CallExpr") and
  not exists(Raw::AdaNode c | c.getParent+() = right and c.getAPrimaryQlClass() = "CallExpr")
select op, "Both operands of this expression are " + left.getText() + "."
