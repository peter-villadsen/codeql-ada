/**
 * @name Expression with too many items
 * @description An expression of more than 20 primaries joined by operators is hard to
 *              read and to check; name some of its parts. AdaControl rule
 *              `Max_Expression_Items` with 20. Other limits are in
 *              `codeql.ada.adacontrol.MaxExpressionItems` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/max-expression-items
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxExpressionItems

from Expr e, int n
where
  MaxExpressionItems::isWhole(e) and
  n = MaxExpressionItems::items(e) and
  n > 20 and
  e.fromSource()
select e, "This expression has " + n + " items, more than 20."
