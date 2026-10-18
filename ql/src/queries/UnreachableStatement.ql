/**
 * @name Unreachable statement
 * @description A statement that no control-flow path from the start of its enclosing
 *              subprogram, task, entry, or package body can ever reach (only the first
 *              unreachable statement in a run is flagged).
 * @id ada/unreachable-statement
 * @kind problem
 * @problem.severity warning
 * @tags maintainability correctness
 */

import ada
import codeql.ada.controlflow.ControlFlowGraph

/**
 * Holds if `stmt` is ever executed: control reaches the point before it. (Not "the node
 * that represents it": that follows the parts of an assignment or a call statement.)
 */
private predicate isReachable(AdaNode stmt) { exists(ControlFlowNode n | n.isBefore(stmt)) }

from StmtList list, int i, AdaNode stmt
where
  stmt = list.getChild(i) and
  not isReachable(stmt) and
  (i = 0 or isReachable(list.getChild(i - 1))) and
  // a pragma is not executed; `pragma Annotate (Xcov, Exempt_Off)` after a `raise`
  // is the usual way to close a coverage exemption
  not stmt instanceof PragmaNode and
  // the CFG does not model GNAT's `finally` extension yet
  not stmt.getParent+() instanceof FinallyPart and
  stmt.fromSource()
select stmt, "This statement is unreachable."
