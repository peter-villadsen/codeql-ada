/**
 * @name Comparison with boolean literal
 * @description Comparing a boolean expression to `True` or `False` is redundant: the
 *              expression itself (or its negation) already carries that value.
 * @id ada/boolean-literal-comparison
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability readability
 */

import ada

from Raw::RelationOp cmp, Name lit
where
  (cmp.getOp() instanceof Raw::OpEq or cmp.getOp() instanceof Raw::OpNeq) and
  lit = [cmp.getLeft(), cmp.getRight()] and
  lit.getText().toLowerCase() = ["true", "false"]
select cmp, "Comparison with boolean literal " + lit.getText() + " is redundant."
