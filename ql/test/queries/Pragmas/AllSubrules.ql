/**
 * Every predicate of `codeql.ada.adacontrol.Pragmas`, for the shipped query's test
 * sources: each pragma's name (`all`), `nonstandard` and `multiple`.
 */

import ada
import codeql.ada.adacontrol.Pragmas

from PragmaNode p, string what
where
  p.fromSource() and
  (
    what = "name " + Pragmas::pragmaName(p)
    or
    Pragmas::isNonstandard(p) and what = "nonstandard"
    or
    Pragmas::isMultiple(p) and what = "multiple"
  )
select p, what
