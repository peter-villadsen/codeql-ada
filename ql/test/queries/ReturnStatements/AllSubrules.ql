/**
 * Every subrule of `codeql.ada.adacontrol.ReturnStatements`, for the shipped query's test
 * sources: each return's depth and callable, `regular_count`, `handler_count`.
 */

import ada
import codeql.ada.adacontrol.ReturnStatements

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(AdaNode c | c = ReturnStatements::callable(n) |
      what =
        "depth " + ReturnStatements::depth(n) + " in a " + ReturnStatements::callableKind(c)
    )
    or
    what = "regular_count " + ReturnStatements::regularCount(n)
    or
    exists(ExceptionHandler h |
      what = "handler_count " + ReturnStatements::handlerCount(n, h) + " at line " + h.getLocation().getStartLine()
    )
  )
select n, what
