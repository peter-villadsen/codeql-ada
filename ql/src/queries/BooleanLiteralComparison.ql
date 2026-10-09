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
  lit.getReferencedDecl().hasQualifiedName(["Standard.Boolean.True", "Standard.Boolean.False"])
  or
  not exists(lit.getReferencedDecl()) and lit.getText().toLowerCase() = ["true", "false"]
}

/**
 * Holds if `e` is known to be of a boolean type: `Standard.Boolean` or a type derived
 * from it. A comparison with `True` is redundant only then; `X = True` where `X` is of
 * some other type with a literal `True` converts it, and an operand whose type did
 * not resolve (a missing dependency) cannot be judged.
 */
private predicate isOfBooleanType(Expr e) {
  e.getType().getParentType*().hasQualifiedName("Standard.Boolean")
}

from RelationOp cmp, Name lit, Expr other
where
  (cmp.getOp() instanceof OpEq or cmp.getOp() instanceof OpNeq) and
  lit = [cmp.getLeft(), cmp.getRight()] and
  other = [cmp.getLeft(), cmp.getRight()] and
  other != lit and
  isBooleanLiteral(lit) and
  isOfBooleanType(other) and
  cmp.fromSource()
select cmp, "Comparison with boolean literal " + lit.getText() + " is redundant."
