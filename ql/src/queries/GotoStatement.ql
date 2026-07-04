/**
 * @name Goto statement
 * @description `goto` statements make control flow harder to follow and verify.
 *              GNATcheck: `goto_statements`.
 * @id ada/goto-statement
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

from Raw::GotoStmt g
select g, "Use of goto statement."
