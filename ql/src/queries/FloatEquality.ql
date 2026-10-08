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

// Predefined types (`Float`, `Long_Float`, ...) resolve into package `Standard`, which is
// extracted as a pseudo-source (D-026). Limitation: only direct type declarations are
// matched; subtypes and derived-type chains to a floating-point base are not followed.
from RelationOp cmp, Expr operand
where
  (cmp.getOp() instanceof OpEq or cmp.getOp() instanceof OpNeq) and
  operand = [cmp.getLeft(), cmp.getRight()] and
  operand.getType().(TypeDecl).getTypeDef() instanceof FloatingPointDef and
  cmp.fromSource()
select cmp, "This comparison uses floating-point equality."
