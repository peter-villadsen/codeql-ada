/**
 * @name Access value of a local entity
 * @description Taking `'Access`, `'Unchecked_Access` or `'Unrestricted_Access` of an
 *              object or subprogram that is not declared in a library package creates an
 *              access value that can outlive what it designates: a failing accessibility
 *              check at run time, or with `'Unchecked_Access` a dangling pointer. AdaControl
 *              rule `Local_Access`, all categories. See
 *              `codeql.ada.adacontrol.LocalAccess` (`docs/adacontrol.md`).
 * @id ada/local-access
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.LocalAccess

from AttributeRef a, BasicDecl entity, string category
where
  LocalAccess::localAccess(a, entity, category) and
  a.fromSource()
select a,
  "'" + a.getAttribute().getValue() + " of local " + category.replaceAll("_", " ") + " $@.",
  entity, entity.getAName()
