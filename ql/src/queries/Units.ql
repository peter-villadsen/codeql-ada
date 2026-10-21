/**
 * @name Unreferenced library package
 * @description A library package that no unit of the project withs, and that has no
 *              child unit, is dead code, or a unit the project forgot to use. AdaControl
 *              rule `Units` with `unreferenced`, for packages: unreferenced subprograms
 *              are mostly main programs. `unchecked` is the extractor's report of missing
 *              units, not a query. See `codeql.ada.adacontrol.Units`
 *              (`docs/adacontrol.md`).
 * @id ada/units
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Units

from BasicDecl d
where
  Units::isUnreferenced(d) and
  (d instanceof PackageDecl or d instanceof GenericPackageDecl) and
  d.fromSource()
select d, "No unit withs package " + d.getQualifiedName() + "."
