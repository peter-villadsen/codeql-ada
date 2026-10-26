/**
 * Every construct `codeql.ada.adacontrol.BarrierExpressions` finds in the shipped
 * query's test sources, with its keyword.
 */

import ada
import codeql.ada.adacontrol.BarrierExpressions

from Expr n, EntryBody b, string kw
where BarrierExpressions::construct(n, b, kw)
select n, b.getEntryName().getName().getText() + ": " + kw
