/**
 * Every subrule of `codeql.ada.adacontrol.EntityInsideException`, for the shipped
 * query's test sources: an entity (through renamings), `calls`, `entry_calls`.
 */

import ada
import codeql.ada.adacontrol.EntityInsideException

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(BasicDecl e |
      e.hasQualifiedName("Ada.Text_IO.Put_Line") and
      EntityInsideException::referenceIn(n, _, e) and
      what = "references Put_Line"
    )
    or
    EntityInsideException::callIn(n, _) and what = "calls"
    or
    EntityInsideException::entryCallIn(n, _) and what = "entry_calls"
  )
select n, what
