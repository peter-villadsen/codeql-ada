/**
 * `codeql.ada.adacontrol.NotSelectedName` on the shipped query's test sources: every
 * simple reference to `Stacks.Object`, and the exception places that allow it.
 */

import ada
import codeql.ada.adacontrol.NotSelectedName

from Identifier id, Type t
where
  t.hasQualifiedName("Stacks.Object") and
  NotSelectedName::simpleReference(id, t) and
  id.fromSource()
select id,
  concat(string place |
    place = ["none", "unit", "compilation", "family"] and
    NotSelectedName::notSelected(id, t, place)
  |
    place, ", "
  )
