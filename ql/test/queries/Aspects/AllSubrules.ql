/**
 * Every predicate of `codeql.ada.adacontrol.Aspects`, for the shipped query's test
 * sources: each aspect's mark (all aspects), a given mark, `implicit_true`.
 */

import ada
import codeql.ada.adacontrol.Aspects

from AspectAssoc a, string what
where
  a.fromSource() and
  (
    what = "mark " + Aspects::aspectMark(a)
    or
    Aspects::hasAspectMark(a, ["pre", "post'class", "PRE'CLASS"]) and what = "given mark"
    or
    Aspects::isImplicitTrue(a) and what = "implicit_true"
  )
select a, what
