/**
 * @name Unused local object
 * @description A local object declaration that no name in the project resolves
 *              to is dead code. (Multi-name declarations count as used if any
 *              of their names is used.) Not reported: objects marked `with
 *              Unreferenced` or named in `pragma Unreferenced`, and objects whose
 *              name appears, unresolved, in the enclosing body (a reference
 *              extraction could not resolve, usually a missing dependency; D-026).
 * @id ada/unused-local
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

from ObjectDecl d, BaseSubpBody b
where
  b = d.getEnclosingSubprogram() and
  not d.isReferenced() and
  // A same-named name that did not resolve may be a use (missing dependencies, D-026).
  // Checking every enclosing body amounts to checking the innermost one.
  not d.hasUnresolvedNamesakeIn(b) and
  not d.isMarkedUnreferenced() and
  not exists(d.getRenamingClause()) and
  // An extended-return object is the returned value; "unused" is meaningless.
  not d instanceof ExtendedReturnStmtObjectDecl and
  d.fromSource()
select d, "Local object " + d.getAName() + " is never referenced."
