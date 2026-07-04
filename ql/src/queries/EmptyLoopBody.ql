/**
 * @name Empty loop body
 * @description A loop whose body is only `null;` does no work and either is a leftover
 *              stub or, for `while`/`for` loops with a condition depending on an external
 *              actor, an unintentional busy-wait.
 * @id ada/empty-loop-body
 * @kind problem
 * @problem.severity warning
 * @tags correctness concurrency
 */

import ada

from Raw::BaseLoopStmt s, Raw::StmtList stmts
where
  stmts = s.getStmts() and
  stmts.getChild(0) instanceof Raw::NullStmt and
  not exists(stmts.getChild(1))
select s, "This loop's body does nothing."
