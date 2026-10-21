/**
 * @name Declarations nested too deeply
 * @description A declarative construct (package, subprogram, task, block, ...) nested in
 *              more than 7 others is hard to follow. AdaControl rule `Max_Nesting` with
 *              `all, 7`. Other limits, and the subrules `generic` and `task`, are in
 *              `codeql.ada.adacontrol.MaxNesting` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/max-nesting
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxNesting

from AdaNode n, int depth
where depth = MaxNesting::depth(n, "all") and depth > 7 and n.fromSource()
select n, "This is nested " + depth + " deep, more than 7."
