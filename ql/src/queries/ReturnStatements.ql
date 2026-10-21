/**
 * @name Too many return statements
 * @description A subprogram whose statements have more than 5 return statements has as
 *              many exits to follow when reading or changing it. AdaControl rule
 *              `Return_Statements` with `regular_count, max 5`. The subrules `depth` and
 *              `handler_count`, other bounds and callable kinds are in
 *              `codeql.ada.adacontrol.ReturnStatements` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/return-statements
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.ReturnStatements

from SubpBody b, int n
where n = ReturnStatements::regularCount(b) and n > 5 and b.fromSource()
select b, b.getAName() + " has " + n + " return statements, more than 5."
