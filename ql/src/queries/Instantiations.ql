/**
 * @name Duplicate unchecked instantiation
 * @description A second instance of `Unchecked_Conversion` or `Unchecked_Deallocation`
 *              with the same actuals as an earlier one: one instance would do, and each
 *              copy is one more place to review. AdaControl rule `Instantiations` with
 *              `Ada.Unchecked_Conversion, =, =` and `Ada.Unchecked_Deallocation, =, =`.
 *              Instantiations of other generics, with given actuals or categories, and
 *              at given places, are in `codeql.ada.adacontrol.Instantiations` for a query
 *              of your own (`docs/adacontrol.md`).
 * @id ada/instantiations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Instantiations

from GenericInstantiation inst, GenericInstantiation previous, BasicDecl generic
where
  generic.hasQualifiedName([
      "Ada.Unchecked_Conversion", "Unchecked_Conversion", "Ada.Unchecked_Deallocation",
      "Unchecked_Deallocation"
    ]) and
  Instantiations::instantiates(inst, generic) and
  Instantiations::repeats(inst, "0,1", previous) and
  inst.fromSource() and
  previous.fromSource()
select inst, "This instance of " + generic.getAName() + " repeats $@ with the same actuals.",
  previous, previous.getAName()
