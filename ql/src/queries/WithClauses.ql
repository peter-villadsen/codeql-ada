/**
 * @name Redundant with clause
 * @description A `with` clause for a unit already withed by the same unit, by the spec of
 *              this body, or for an ancestor of the unit (always visible) adds nothing.
 *              AdaControl rule `With_Clauses`, the redundant part of `reduceable`; the
 *              unused part is `ada/unused-with-clause`. Movable `with` clauses,
 *              `multiple_names`, `inherited`, `limited` and `private` are in
 *              `codeql.ada.adacontrol.WithClauses` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/with-clauses
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.WithClauses

from CompilationUnit cu, Name withName, string msg
where
  withName.fromSource() and
  (
    exists(Name earlier | WithClauses::isRedundant(cu, withName, earlier) |
      msg = withName.getText() + " is already withed, at line " + earlier.getLocation().getStartLine() + " of " + earlier.getLocation().toString().regexpCapture("(?:.*/)?([^/:]+):.*", 1) + "."
    )
    or
    WithClauses::withsAncestor(cu, withName) and
    msg = withName.getText() + " is an ancestor of this unit, always visible."
  )
select withName, msg
