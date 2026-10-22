/** Every metric of `codeql.ada.adacontrol.CaseStatement`, for the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.CaseStatement

from CaseStmt c, string what
where
  c.fromSource() and
  (
    what = "paths " + CaseStatement::paths(c)
    or
    what = "values " + CaseStatement::values(c)
    or
    what = "values_if_others " + CaseStatement::valuesIfOthers(c)
    or
    what = "others_span " + CaseStatement::othersSpan(c)
    or
    what = "category " + CaseStatement::selectorCategory(c)
    or
    exists(BinOp r | what = "range_span " + CaseStatement::rangeSpan(c, r))
  )
select c, what
