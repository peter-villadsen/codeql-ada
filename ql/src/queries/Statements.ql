/**
 * @name Backward goto or null case others
 * @description A `goto` to a label before it builds a loop without saying so; a `when
 *              others => null` alternative of a `case` statement silently ignores every
 *              value not listed, including those added to the type later. AdaControl rule
 *              `Statements` with `backward_goto` and `case_others_null`. About seventy
 *              more statement kinds are in `codeql.ada.adacontrol.Statements` for a query
 *              of your own (`docs/adacontrol.md`); `ada/goto-statement`,
 *              `ada/raise-predefined-exception` and `ada/empty-loop-body` are `goto`,
 *              `raise_standard` and `null_loop_body`.
 * @id ada/statements
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Statements

from Stmt s, string msg
where
  s.fromSource() and
  (
    Statements::statement(s, "backward_goto") and
    msg = "This goto jumps back to a label before it: write a loop."
    or
    Statements::statement(s, "case_others_null") and
    msg = "This case statement ignores every other value with when others => null."
  )
select s, msg
