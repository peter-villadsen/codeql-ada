/**
 * Every predicate of `codeql.ada.adacontrol.Instantiations`, for the shipped query's
 * test sources: the generic, actuals by entity (with and without subtypes) and by
 * category, `=` at each position list, and places.
 */

import ada
import codeql.ada.adacontrol.Instantiations
import codeql.ada.adacontrol.Places

from GenericInstantiation inst, string what
where
  inst.fromSource() and
  (
    exists(BasicDecl g | Instantiations::instantiates(inst, g) | what = "of " + g.getQualifiedName())
    or
    exists(int i, BasicDecl e, boolean subtypes |
      e.hasQualifiedName("Standard.Integer") and
      Instantiations::actualIs(inst, i, e, subtypes) and
      what = "actual " + i + " is Integer (subtypes: " + subtypes + ")"
    )
    or
    exists(int i, string c |
      c = ["mod", "range", "access"] and
      Instantiations::actualIsOfCategory(inst, i, c) and
      what = "actual " + i + " of category " + c
    )
    or
    exists(string positions, GenericInstantiation previous |
      Instantiations::repeats(inst, positions, previous) and
      what = "repeats " + previous.getAName() + " at " + positions
    )
    or
    exists(string place | Places::isAt(inst, place) | what = "place " + place)
  )
select inst, what
