/**
 * Every kind of `codeql.ada.adacontrol.RepresentationClauses`, for the shipped query's
 * test sources, with `global` and `object`.
 */

import ada
import codeql.ada.adacontrol.RepresentationClauses

from AdaNode c, string what
where
  c.fromSource() and
  (
    exists(string kw | RepresentationClauses::representation(c, kw) | what = kw)
    or
    exists(RepresentationClauses::target(c)) and
    RepresentationClauses::isGlobal(c) and
    what = "global"
    or
    RepresentationClauses::isForObject(c) and what = "object"
  )
select c, what
