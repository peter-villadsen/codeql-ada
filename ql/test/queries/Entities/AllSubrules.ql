/**
 * Every predicate of `codeql.ada.adacontrol.Entities`, with every place of
 * `Places::useIsAt`, for the shipped query's test sources.
 */

import ada
import codeql.ada.adacontrol.Entities
import codeql.ada.adacontrol.Places

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(BasicDecl e, boolean instanceOnly |
      e.hasQualifiedName(["Debug.Trace", "Debug.Dump"]) and
      Entities::uses(n, e, instanceOnly) and
      what =
        "uses " + e.getQualifiedName() + " (instance only: " + instanceOnly + ") at " +
          concat(string p | Places::useIsAt(n, p) | p, ", ")
    )
    or
    Entities::usesAttribute(n, "UNCHECKED_ACCESS") and what = "attribute Unchecked_Access"
  )
select n, what
