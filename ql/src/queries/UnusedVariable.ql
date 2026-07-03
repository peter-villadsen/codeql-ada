/**
 * @name Unused local object
 * @description A local object declaration that no name in the project resolves
 *              to is dead code. (Multi-name declarations count as used if any
 *              of their names is used.)
 * @id ada/unused-local
 * @kind table
 * @tags maintainability
 */

import ada

from Raw::ObjectDecl d
where
  exists(Raw::BaseSubpBody b | d.(AdaNode).getEnclosingSubprogram() = b) and
  not d.(BasicDecl).isReferenced() and
  not exists(d.getRenamingClause()) and
  // An extended-return object is the returned value; "unused" is meaningless.
  not d instanceof Raw::ExtendedReturnStmtObjectDecl
select d, "Local object " + d.(BasicDecl).getAName() + " is never referenced."
