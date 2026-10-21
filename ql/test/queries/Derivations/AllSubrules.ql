/**
 * Every subrule of `codeql.ada.adacontrol.Derivations`, for the shipped query's test
 * sources: `from` (a type, a subtype, a unit, a category), `max_parents`, `max_depth`,
 * and `indicator` on declarations and bodies.
 */

import ada
import codeql.ada.adacontrol.Derivations

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(Type t | t = n and Derivations::isDerived(t) |
      exists(BasicDecl a | Derivations::derivesFrom(t, a) |
        what = "from " + a.getQualifiedName()
      )
      or
      exists(string c |
        c = ["tagged", "interface", "range"] and
        Derivations::derivesFromCategory(t, c) and
        what = "from category " + c
      )
      or
      what =
        "parents " + Derivations::parentCount(t) + ", depth " + Derivations::depth(t)
    )
    or
    exists(Subprogram s, string expected, boolean onBody |
      Derivations::missingIndicator(s, n, expected, onBody) and
      what = "missing " + expected + " (body: " + onBody + ")"
    )
    or
    Derivations::indicatorOnBody(_, n) and what = "indicator on body"
  )
select n, what
