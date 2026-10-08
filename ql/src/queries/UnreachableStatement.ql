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
import codeql.ada.controlflow.Cfg

/** Holds if `n` is part of the analyzed control flow, i.e. has a CFG node. */
private predicate hasCfgNode(AdaNode n) { exists(AstCfgNode cfn | cfn.getAstNode() = n) }

/**
 * Holds if `stmt` is ever executed: its control-flow entry point (which, for
 * a compound statement, may differ from `stmt` itself -- e.g. an `if`'s
 * guard) has a CFG node. This is deliberately not "`stmt` has a CFG node"
 * directly: a compound statement all of whose branches complete abruptly
 * (e.g. an `if`/`else` that both `return`) never reaches its own
 * normal-completion join node, even though it plainly executes.
 */
private predicate isReachable(AdaNode stmt) { hasCfgNode(getAControlFlowEntryNode(stmt)) }

from StmtList list, int i, AdaNode stmt
where
  stmt = list.getChild(i) and
  not isReachable(stmt) and
  (i = 0 or isReachable(list.getChild(i - 1))) and
  stmt.fromSource()
select stmt, "This statement is unreachable."
