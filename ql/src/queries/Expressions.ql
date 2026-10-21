/**
 * @name Unary minus applied to mod or rem
 * @description `-A mod B` is `-(A mod B)`, not `(-A) mod B`, and the two differ: the
 *              result has the other sign. AdaControl rule `Expressions`, the unary case
 *              of subrule `mixed_operators`. The binary case (`A + B * C`), and about
 *              fifty more expression kinds, are in `codeql.ada.adacontrol.Expressions`
 *              for a query of your own (`docs/adacontrol.md`); `ada/float-equality` is
 *              `real_equality`.
 * @id ada/expressions
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags correctness readability adacontrol
 */

import ada
import codeql.ada.adacontrol.Expressions

from UnOp e
where Expressions::expression(e, "mixed_operators") and e.fromSource()
select e,
  "This is the negation of the whole " + e.getExpr().(BinOp).getOp().toString() +
    " expression: parenthesize to say which is meant."
