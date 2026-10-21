/**
 * Every keyword of `codeql.ada.adacontrol.Expressions`, for the shipped query's test
 * sources.
 */

import ada
import codeql.ada.adacontrol.Expressions

from Expr e, string kw
where Expressions::expression(e, kw) and e.fromSource()
select e, kw
