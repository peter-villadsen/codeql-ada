/**
 * @name Unit depends on its own child
 * @description A unit that withs one of its own child units makes the parent depend on
 *              the child as well as the child on the parent, which a coding standard
 *              may forbid as a cycle in the design. AdaControl rule `Dependencies`,
 *              subrules `public_child` and `private_child`. The subrules `with`,
 *              `others`, `raw`, `direct` and `parent` are in
 *              `codeql.ada.adacontrol.Dependencies` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/dependencies
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Dependencies

from CompilationUnit cu, Name withName, boolean isPrivate, string kind
where
  Dependencies::dependsOnOwnChild(cu, withName, isPrivate) and
  withName.fromSource() and
  if isPrivate = true then kind = "private" else kind = "public"
select withName,
  Dependencies::unitName(cu) + " depends on its own " + kind + " child unit " +
    withName.getText() + "."
