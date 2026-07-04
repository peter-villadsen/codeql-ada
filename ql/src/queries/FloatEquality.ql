/**
 * @name Floating-point equality comparison
 * @description Comparing floating-point values with `=` or `/=` is fragile because
 *              rounding error means two mathematically equal expressions can differ in
 *              their least significant bits.
 * @id ada/float-equality
 * @kind problem
 * @problem.severity warning
 * @tags correctness numerics
 */

import ada

// Limitation: only catches user-declared floating-point types. `ada_expr_type` is only
// emitted when the resolved type declaration is itself in the analyzed source set, so
// predefined types (`Float`, `Long_Float`, ...), which live in package `Standard`, never
// resolve here. Derived-type chains to a user-declared float base are also not followed
// (v1 matches direct type decls only).
from Raw::RelationOp cmp, Expr operand
where
  (cmp.getOp() instanceof Raw::OpEq or cmp.getOp() instanceof Raw::OpNeq) and
  operand = [cmp.getLeft(), cmp.getRight()] and
  operand.getType().(Raw::TypeDecl).getTypeDef() instanceof Raw::FloatingPointDef
select cmp, "This comparison uses floating-point equality."
