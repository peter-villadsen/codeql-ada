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

/**
 * Holds if `lit` denotes `Standard.Boolean`'s `True` or `False` (D-026), however
 * spelled -- including `Standard.True` and the inherited literals of a type derived
 * from `Boolean` -- but not a user enumeration literal named `True`. Only if `lit` does
 * not resolve (no GNAT runtime at extraction) is its text used.
 */
private predicate isBooleanLiteral(Name lit) {
  lit.getReferencedDecl()
      
      .hasQualifiedName(["Standard.Boolean.True", "Standard.Boolean.False"])
  or
  not exists(lit.getReferencedDecl()) and lit.getText().toLowerCase() = ["true", "false"]
}

from RelationOp cmp, Name lit
where
  (cmp.getOp() instanceof OpEq or cmp.getOp() instanceof OpNeq) and
  lit = [cmp.getLeft(), cmp.getRight()] and
  isBooleanLiteral(lit) and
  cmp.fromSource()
select cmp, "Comparison with boolean literal " + lit.getText() + " is redundant."
