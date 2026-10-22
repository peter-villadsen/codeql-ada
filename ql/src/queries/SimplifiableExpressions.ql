/**
 * @name Simplifiable expression
 * @description An expression that can be written more simply: a conversion to the type it
 *              already has (or of a literal), `A and A` (often a copy-paste slip), `not`
 *              of a comparison, several tests of one variable that one membership test
 *              can replace, `T'First .. T'Last` for `T'Range`. AdaControl rule
 *              `Simplifiable_Expressions`, subrules `conversion`, `logical_redundant`,
 *              `logical_not`, `membership` and `range`. `parentheses` and `if_not` (style
 *              preferences) are in `codeql.ada.adacontrol.SimplifiableExpressions` for a
 *              query of your own (`docs/adacontrol.md`); `logical_true` and
 *              `logical_false` are `ada/boolean-literal-comparison`.
 * @id ada/simplifiable-expressions
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.SimplifiableExpressions

/** Gets the message for an expression `subrule` applies to. */
string message(string subrule) {
  subrule = "conversion" and
  result = "This conversion is redundant: the value already has the type, or is universal."
  or
  subrule = "logical_redundant" and
  result = "Both operands of this logical operator are the same: a copy-paste slip?"
  or
  subrule = "logical_not" and result = "Invert this comparison instead of negating it."
  or
  subrule = "membership" and
  result = "These tests of one value can be a single membership test (in, not in)."
  or
  subrule = "range" and result = "Write T'Range (or T) for T'First .. T'Last."
}

from Expr e, string subrule
where SimplifiableExpressions::simplifiable(e, subrule) and e.fromSource()
select e, message(subrule)
