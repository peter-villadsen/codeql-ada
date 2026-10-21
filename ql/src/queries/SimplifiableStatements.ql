/**
 * @name Simplifiable statement
 * @description A statement that can be removed or written more simply without changing
 *              what the program does: a block with nothing of its own, dead code under a
 *              static condition, a handler that only re-raises, an empty `else`, an `if`
 *              chain that is a `case`, a `while True` loop, a loop that starts with its
 *              exit, a `null` among other statements, an `if True`, an `if` that assigns
 *              or returns its own condition, and loops that are a slice assignment, a
 *              `for ... of` or a `for` loop. AdaControl rule `Simplifiable_Statements`,
 *              all subrules but `nested_path` and `if_not` (style preferences), and
 *              without the part of `dead` after a `return` or `goto`, which
 *              `ada/unreachable-statement` reports. Every subrule, with the modifiers
 *              `no_exit` and `full_range`, is in
 *              `codeql.ada.adacontrol.SimplifiableStatements` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/simplifiable-statements
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.SimplifiableStatements

/** Gets the message for a statement `subrule` applies to. */
string message(string subrule) {
  subrule = "block" and result = "This block has no name, declarations or handlers: remove it."
  or
  subrule = "dead" and result = "This code never runs: its condition is static."
  or
  subrule = "for_for_slice" and result = "This loop can be a slice or aggregate assignment."
  or
  subrule = "for_in_for_for_of" and
  result = "This loop only uses its index to index one array: use for ... of."
  or
  subrule = "handler" and result = "This handler only re-raises: remove it."
  or
  subrule = "if" and result = "This else part only holds null: remove it."
  or
  subrule = "if_for_case" and
  result = "These conditions compare one variable with static values: use a case statement."
  or
  subrule = "loop" and result = "This while loop's condition is always True: use a plain loop."
  or
  subrule = "loop_for_while" and
  result = "This loop starts with its exit: use a while loop."
  or
  subrule = "null" and result = "This null statement does nothing: remove it."
  or
  subrule = "true_if" and result = "This condition is always True."
  or
  subrule = "unnecessary_if" and
  result = "This if assigns or returns its own condition: use the condition directly."
  or
  subrule = "while_for_for" and
  result = "This while loop steps one variable to a bound: use a for loop."
}

from AdaNode s, string subrule
where
  SimplifiableStatements::simplifiable(s, subrule) and
  exists(message(subrule)) and
  not (subrule = "dead" and SimplifiableStatements::deadAfterJump(s)) and
  s.fromSource()
select s, message(subrule)
