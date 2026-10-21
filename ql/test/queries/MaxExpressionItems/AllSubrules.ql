/** `MaxExpressionItems::items` of every whole expression of the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.MaxExpressionItems

from Expr e
where MaxExpressionItems::isWhole(e) and e.fromSource()
select e, MaxExpressionItems::items(e)
