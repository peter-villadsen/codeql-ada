/**
 * @name Record type without an initial value constant
 * @description A record type declared without a constant of the type in the same
 *              declarative part (`Null_Item : constant Item := ...`) leaves each user to
 *              build an initial value of their own. AdaControl rule `Type_Initial_Values`,
 *              for record and private types. Other types and a name pattern are in
 *              `codeql.ada.adacontrol.TypeInitialValues` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/type-initial-values
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.TypeInitialValues

from Type t
where
  TypeInitialValues::lacksInitialValue(t, "") and
  (t.isRecord() or t.isPrivate()) and
  t.fromSource()
select t, t.getName() + " has no initial value constant declared with it."
