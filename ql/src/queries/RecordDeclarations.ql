/**
 * @name Uninitialized discrete record component
 * @description A record component of an enumeration type without a default value starts
 *              each record with an arbitrary, possibly invalid, value. AdaControl rule
 *              `Record_Declarations` with `component, (), not initialized`. Components of
 *              other types and categories, and the conditions `in_variant`, `aligned`,
 *              `packed` and `sized`, are in `codeql.ada.adacontrol.RecordDeclarations`
 *              for a query of your own (`docs/adacontrol.md`).
 * @id ada/record-declarations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.RecordDeclarations

from Component c
where
  RecordDeclarations::isOfCategory(c, "()") and
  not RecordDeclarations::isInitialized(c) and
  c.fromSource()
select c, "Component " + c.getName() + " of an enumeration type has no default value."
