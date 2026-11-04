/**
 * Every access to a package-body global that `codeql.ada.adacontrol.DirectlyAccessedGlobals`
 * sees in the shipped query's test sources: its mode, the callable's kind and accessor,
 * and whether that callable is dedicated to the variable.
 */

import ada
import codeql.ada.adacontrol.DirectlyAccessedGlobals

from Variable v, Identifier n, string mode, string where_
where
  DirectlyAccessedGlobals::access(v, n, mode) and
  (
    exists(AdaNode c | c = DirectlyAccessedGlobals::callable(n) |
      where_ =
        concat(DirectlyAccessedGlobals::kind(c)) + " " +
          concat(DirectlyAccessedGlobals::accessorName(DirectlyAccessedGlobals::accessor(c))) +
          any(string d |
            if DirectlyAccessedGlobals::isDedicated(c, v)
            then d = ""
            else d = " not dedicated: " + concat(string r | DirectlyAccessedGlobals::notDedicated(c, v, r) | r, ",")
          )
    )
    or
    not exists(DirectlyAccessedGlobals::callable(n)) and where_ = "outside"
  )
select n, v.getName() + " " + mode + " " + where_
