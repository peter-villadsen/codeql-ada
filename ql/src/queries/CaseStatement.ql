/**
 * @name Case statement with an empty when others
 * @description A `when others` alternative of a `case` statement whose other choices
 *              already cover every value of the selector's subtype is dead code; it also
 *              hides, from the completeness check, a value added to the type later, which
 *              then silently takes this path. AdaControl rule `Case_Statement` with
 *              `others_span, min 1`. The subrules `paths`, `range_span`, `values` and
 *              `values_if_others`, and other bounds, are in
 *              `codeql.ada.adacontrol.CaseStatement` for a query of your own
 *              (`docs/adacontrol.md`). Only static choices and subtypes are counted
 *              (literals, enumeration literals, named numbers, ranges of these).
 * @id ada/case-statement
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags maintainability correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.CaseStatement

from CaseStmt c
where CaseStatement::othersSpan(c) < 1 and c.fromSource()
select c, "The when others alternative of this case statement covers no value."
