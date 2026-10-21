/**
 * Every predicate of `codeql.ada.adacontrol.LocalHiding`, for the shipped query's test
 * sources: `strict` and `overloading`, and what the exceptions test.
 */

import ada
import codeql.ada.adacontrol.LocalHiding

from BasicDecl inner, BasicDecl outer, string what
where
  inner.fromSource() and
  (
    LocalHiding::hides(inner, outer) and
    what =
      "hides (" + LocalHiding::family(inner) + " hides " + LocalHiding::family(outer) + ")"
    or
    LocalHiding::overloads(inner, outer) and what = "overloads"
  )
select inner, what, outer
