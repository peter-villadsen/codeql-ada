/**
 * AdaControl rule `Terminating_Tasks`: tasks that can terminate (`docs/adacontrol.md`).
 *
 * AdaControl judges by the shape of the task body (its last statement is not an
 * unconditional loop, or that loop is exited). Here a task terminates when its body can
 * complete: the normal exit is reached along a feasible path of the control-flow graph
 * (`PathReachability`), or an explicit `raise` propagates out of the body (an unhandled
 * exception ends the task silently); or when it has a `terminate` alternative. Exceptions
 * that calls may raise are not followed: every call may raise, so every task would
 * terminate. An aborted task is not counted, as in AdaControl.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.ControlFlowGraph
private import codeql.ada.controlflow.PathReachability

module TerminatingTasks {
  /**
   * Paths from a scope's entry that leave by an exception only at a `raise`: the
   * exception edges of calls, which the graph adds to every call, are not followed.
   */
  private module RaiseOnly implements PathReachability::ConfigSig {
    predicate isSource(ControlFlowNode n) { n instanceof ControlFlow::EntryNode }

    predicate isSink(ControlFlowNode n) { none() }

    predicate isBarrierEdge(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2) {
      n2 = n1.getASuccessor(t) and
      t instanceof ExceptionSuccessor and
      not n1.getAstNode() instanceof Raw::RaiseStmt and
      not n1.getAstNode() instanceof Raw::RaiseExpr
    }
  }

  /** Holds if the statements of task body `t` can complete normally. */
  predicate completesNormally(Raw::TaskBody t) {
    exists(ControlFlow::NormalExitNode exit |
      exit.getEnclosingCallable() = t and PathReachability::Make<RaiseOnly>::reached(exit)
    )
  }

  /** Holds if an explicit `raise` can propagate out of task body `t`. */
  predicate raisesOut(Raw::TaskBody t) {
    exists(ControlFlow::ExceptionalExitNode exit |
      exit.getEnclosingCallable() = t and PathReachability::Make<RaiseOnly>::reached(exit)
    )
  }

  /** Gets a `terminate` alternative of a selective accept of task body `t` (not of a nested task). */
  Raw::TerminateAlternative terminateAlternative(Raw::TaskBody t) {
    result.getParent+() = t and
    not exists(Raw::TaskBody inner | result.getParent+() = inner and inner.getParent+() = t)
  }

  /** Holds if task body `t` can terminate, for `reason`: `completes`, `raises`, `terminate`. */
  predicate isTerminating(Raw::TaskBody t, string reason) {
    completesNormally(t) and reason = "completes"
    or
    raisesOut(t) and reason = "raises"
    or
    exists(terminateAlternative(t)) and reason = "terminate"
  }
}
