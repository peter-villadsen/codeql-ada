/**
 * @name Use clause in a context clause
 * @description A `use` clause with the `with` clauses makes every declaration of the
 *              package directly visible in the whole unit, so a reader cannot tell where a
 *              name comes from. AdaControl rule `Use_Clauses` with `global`. Local use
 *              clauses, `use type` and `use all type`, and packages to allow are in
 *              `codeql.ada.adacontrol.UseClauses` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/use-clauses
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.UseClauses

from UseClause u, Name n
where UseClauses::controlled(u, n, "global") and u.fromSource()
select n, "use " + n.getText() + " makes all of it visible in the whole unit."
