/**
 * @name Generic type name used without its package
 * @description A type named `Object`, `Instance` or `T` is meant to be read with the name
 *              of its package (`Stacks.Object`); used by its simple name outside its own
 *              package, through a `use` clause, it says nothing. AdaControl rule
 *              `Not_Selected_Name` with `unit, all Object, all Instance, all T`. Other
 *              entities and exception places are in
 *              `codeql.ada.adacontrol.NotSelectedName` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/not-selected-name
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.NotSelectedName

from Identifier id, Type t
where
  t.getName().toLowerCase() = ["object", "instance", "t"] and
  NotSelectedName::notSelected(id, t, "unit") and
  id.fromSource()
select id, "Use the selected name of " + t.getQualifiedName() + "."
