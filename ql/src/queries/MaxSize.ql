/**
 * @name Subprogram body too long
 * @description A subprogram body of more than 200 source lines is hard to understand and
 *              to test; split it. AdaControl rule `Max_Size` with `procedure_body, 200`
 *              and `function_body, 200`. The other kinds (blocks, loops, branches,
 *              packages, units, ...) and limits are in `codeql.ada.adacontrol.MaxSize`
 *              for a query of your own (`docs/adacontrol.md`).
 * @id ada/max-size
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxSize

from SubpBody b, string kind, int n
where
  MaxSize::isElement(b, kind) and
  kind = ["procedure_body", "function_body"] and
  n = MaxSize::lines(b) and
  n > 200 and
  b.fromSource()
select b, b.getAName() + " is " + n + " lines long, more than 200."
