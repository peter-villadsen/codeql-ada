/**
 * @name Unreachable statement
 * @description A statement that no control-flow path from the start of its enclosing
 *              subprogram, task, entry, or package body can ever reach (only the first
 *              unreachable statement in a run is flagged). A statement in an
 *              exception handler is not reported when the statements the handler
 *              protects contain a name that did not resolve: it may be a call that
 *              raises (typically into a dependency that was not extracted), which the
 *              control-flow graph cannot know.
 * @id ada/unreachable-statement
 * @kind problem
 * @problem.severity warning
 * @tags maintainability correctness
 */

import ada
import codeql.ada.controlflow.ControlFlowGraph
import codeql.ada.controlflow.PathReachability

private module FromEntry implements PathReachability::ConfigSig {
  predicate isSource(ControlFlowNode n) { n instanceof ControlFlow::EntryNode }

  predicate isSink(ControlFlowNode n) { none() }
}

/**
 * Holds if `stmt` is ever executed: a feasible path from its scope's entry
 * (`PathReachability`: a GNAT `finally` part continues only the way it was entered)
 * reaches the point before it. (Not "the node that represents it": that follows the
 * parts of an assignment or a call statement.)
 */
private predicate isReachable(AdaNode stmt) {
  exists(ControlFlowNode n | n.isBefore(stmt) and PathReachability::Make<FromEntry>::reached(n))
}

/**
 * Holds if `n` is a name that did not resolve, as used (not declared, nor an `end` name,
 * an attribute designator or a pragma's argument): it may be a call to a subprogram of
 * a dependency that was not extracted (D-026), which may raise.
 */
private predicate isUnresolvedUse(Name n) {
  (n instanceof Identifier or n instanceof DottedName) and
  not exists(n.getReferencedDecl()) and
  not n.getParent() instanceof DefiningName and
  not n.getParent*() instanceof EndName and
  not n = any(AttributeRef a).getAttribute() and
  not n.getParent+() instanceof PragmaNode
}

/**
 * Holds if `stmt` is in an exception handler whose protected statements contain a name
 * that did not resolve: the control-flow graph raises only at calls it resolves and at
 * `raise`, so it may wrongly find the handler unreachable.
 */
private predicate inHandlerOfUnresolvedCode(AdaNode stmt) {
  exists(ExceptionHandler h, HandledStmts hs, Name n |
    stmt.getParent+() = h and
    h = hs.getExceptions().getChild(_) and
    n.getParent+() = hs.getStmts() and
    isUnresolvedUse(n)
  )
}

from StmtList list, int i, AdaNode stmt
where
  stmt = list.getChild(i) and
  not isReachable(stmt) and
  (i = 0 or isReachable(list.getChild(i - 1))) and
  // a pragma is not executed; `pragma Annotate (Xcov, Exempt_Off)` after a `raise`
  // is the usual way to close a coverage exemption
  not stmt instanceof PragmaNode and
  not inHandlerOfUnresolvedCode(stmt) and
  stmt.fromSource()
select stmt, "This statement is unreachable."
