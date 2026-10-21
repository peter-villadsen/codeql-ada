/**
 * Every subrule of `codeql.ada.adacontrol.ReturnType`, for the shipped query's test
 * sources: each kind, and `type` with `Standard.Integer`.
 */

import ada
import codeql.ada.adacontrol.ReturnType

from Subprogram f, string what
where
  f.fromSource() and
  (
    exists(string kind | ReturnType::returnsKind(f, kind) | what = kind)
    or
    exists(Type t, boolean exact |
      t.hasQualifiedName("Standard.Integer") and
      ReturnType::returnsType(f, t, exact) and
      what = "type Integer (exact: " + exact + ")"
    )
  )
select f, what
