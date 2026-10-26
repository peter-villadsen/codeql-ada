/**
 * Every predicate of `codeql.ada.adacontrol.LocalAccess`, for the shipped query's test
 * sources: each access attribute, the entity it designates, its category, and whether it
 * is global.
 */

import ada
import codeql.ada.adacontrol.LocalAccess

from AttributeRef a, string what
where
  a.fromSource() and
  LocalAccess::isAccessAttribute(a) and
  (
    exists(BasicDecl e | e = LocalAccess::entity(a.getPrefix()) |
      what =
        e.getAName() + " " + concat(LocalAccess::category(e), "/") + " " +
          any(string g | if LocalAccess::isGlobal(e) then g = "global" else g = "local")
    )
    or
    not exists(LocalAccess::entity(a.getPrefix())) and what = "unknown"
  )
select a, what
