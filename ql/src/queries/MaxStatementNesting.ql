/**
 * @name Statements nested too deeply
 * @description A compound statement nested in more than 5 others (`if`, loops, `case`,
 *              blocks, ...) is hard to follow; extract a subprogram. AdaControl rule
 *              `Max_Statement_Nesting` with `all, 5`. The subrules `block`, `case`, `if`
 *              and `loop`, and other limits, are in
 *              `codeql.ada.adacontrol.MaxStatementNesting` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/max-statement-nesting
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxStatementNesting

from Stmt s, int depth
where
  depth = MaxStatementNesting::depth(s, "all") and
  depth > 5 and
  // the outermost statement too deep, not each one inside it
  not exists(Stmt outer |
    outer = s.getParent+() and MaxStatementNesting::depth(outer, "all") > 5
  ) and
  s.fromSource()
select s, "This statement is nested " + depth + " deep, more than 5."
