/**
 * @name Type with too many primitive operations
 * @description A type with more than 30 visible primitive operations does too much;
 *              split it. AdaControl rule `Max_Primitives` with `visible, 30`. The subrule
 *              `total`, `tagged` and `untagged`, and other limits, are in
 *              `codeql.ada.adacontrol.MaxPrimitives` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/max-primitives
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxPrimitives

from Type t, int n
where n = MaxPrimitives::visibleCount(t) and n > 30 and t.fromSource()
select t, t.getName() + " has " + n + " visible primitive operations, more than 30."
