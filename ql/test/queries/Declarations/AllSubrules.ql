/**
 * Every keyword of `codeql.ada.adacontrol.Declarations`, and every place of
 * `codeql.ada.adacontrol.Places`, for the shipped query's test sources.
 */

import ada
import codeql.ada.adacontrol.Declarations
import codeql.ada.adacontrol.Places

from AdaNode d, string what
where
  d.fromSource() and
  (
    exists(string kw | Declarations::declaration(d, kw) and kw != "any_declaration" | what = kw)
    or
    Declarations::declaration(d, "any_declaration") and
    exists(string place |
      Places::isAt(d, place) and place != "nested" and place != "local" and place != "library"
    |
      what = "place " + place
    )
    or
    Declarations::declaration(d, "any_declaration") and
    Places::isAt(d, "local") and
    not d.getParent*() instanceof ParamSpec and
    not d.getParent*() instanceof GenericFormal and
    what = "place local"
  )
select d, what
