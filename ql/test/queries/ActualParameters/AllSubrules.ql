/**
 * Every subrule of `codeql.ada.adacontrol.ActualParameters`, for the shipped query's
 * test sources: `default_used`, `default_not_used`, `default_positional`, and `entity`
 * with and without `all`.
 */

import ada
import codeql.ada.adacontrol.ActualParameters

from AdaNode site, string subrule, string formal, string actual
where
  exists(DefiningName f | formal = ActualParameters::formalName(f) |
    ActualParameters::defaultUsed(site, f) and subrule = "default_used" and actual = ""
    or
    exists(Expr a | actual = a.toString() |
      ActualParameters::defaultNotUsed(site, f, a) and subrule = "default_not_used"
      or
      ActualParameters::defaultPositional(site, f, a) and subrule = "default_positional"
      or
      exists(BasicDecl e, boolean anywhere |
        e.hasQualifiedName(["Ada.Unchecked_Conversion", "Test.I"]) and
        ActualParameters::entityActual(site, f, a, e, anywhere) and
        subrule = "entity " + e.getQualifiedName() + " (anywhere: " + anywhere + ")"
      )
    )
  ) and
  site.fromSource()
select site, subrule, formal, actual
