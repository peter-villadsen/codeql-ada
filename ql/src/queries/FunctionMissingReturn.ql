/**
 * @name Function missing return
 * @description A function body whose control flow can fall off the end without
 *              executing a `return` statement raises `Program_Error` at run time --
 *              legal to compile, but always a bug.
 * @id ada/function-missing-return
 * @kind problem
 * @problem.severity error
 * @tags correctness
 */

import ada
import codeql.ada.controlflow.ControlFlowGraph
import codeql.ada.controlflow.PathReachability

/**
 * Holds if `n` is a call statement whose callee did not resolve (typically a missing
 * dependency, D-026) and is spelled like a `No_Return` subprogram and like no other
 * subprogram: it very likely does not return either. A resolved call to a `No_Return`
 * subprogram needs no help; the CFG gives it no normal successor.
 */
private predicate isUnresolvedNoReturnCall(AdaNode n) {
  exists(Name callee, string last |
    callee = [n.(CallStmt).getCall(), n.(CallStmt).getCall().(CallExpr).getName()] and
    not exists(callee.getReferencedDecl()) and
    last = callee.getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase() and
    exists(Subprogram s | s.getName().toLowerCase() = last and s.isNoReturn()) and
    not exists(Subprogram s | s.getName().toLowerCase() = last and not s.isNoReturn())
  )
}

/**
 * Holds if control can reach `n` from the entry of `body` without passing through an
 * unresolved call to a `No_Return` subprogram (`isUnresolvedNoReturnCall`): control
 * does not come back from such a call, although the CFG cannot know it.
 */
private module AvoidingNoReturn implements PathReachability::ConfigSig {
  predicate isSource(ControlFlowNode n) { n instanceof ControlFlow::EntryNode }

  predicate isSink(ControlFlowNode n) { none() }

  predicate isBarrierEdge(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2) {
    isUnresolvedNoReturnCall(n1.getAstNode()) and n2 = n1.getASuccessor(t)
  }
}

/**
 * Holds if control can reach `n` in `body` along a feasible path (`PathReachability`:
 * a GNAT `finally` part continues only the way it was entered) that does not pass
 * through an unresolved call to a `No_Return` subprogram.
 */
private predicate reachableAvoidingNoReturn(ControlFlowNode n, SubpBody body) {
  PathReachability::Make<AvoidingNoReturn>::reached(n) and n.getEnclosingCallable() = body
}

/**
 * Holds if the statements of `body` can complete normally: a plain edge into the normal
 * exit, which a `return` reaches by a return edge instead.
 */
private predicate fallsOffEnd(SubpBody body) {
  exists(ControlFlowNode last, ControlFlow::NormalExitNode exit, DirectSuccessor t |
    last.getASuccessor(t) = exit and
    exit.getEnclosingCallable() = body and
    reachableAvoidingNoReturn(last, body)
  )
}

from SubpBody body
where
  body.getSubpSpec().getSubpKind() instanceof SubpKindFunction and
  fallsOffEnd(body) and
  body.fromSource()
select body,
  "This function may run off the end without executing a return statement, which raises Program_Error at run time."
