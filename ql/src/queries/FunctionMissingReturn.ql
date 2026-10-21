/**
 * @name Function missing return
 * @description A function body whose control flow can fall off the end without
 *              executing a `return` statement raises `Program_Error` at run time --
 *              legal to compile, but always a bug. An exception handler of the
 *              function's body that can complete normally is reported by itself.
 *              (AdaControl rule `Abnormal_Function_Return`, decided along feasible
 *              control-flow paths rather than by the shape of the last statement.)
 * @id ada/function-missing-return
 * @kind problem
 * @problem.severity error
 * @precision high
 * @tags correctness adacontrol
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

/** Gets an exception handler of the statements of `body` itself (not of a nested block). */
private ExceptionHandler bodyHandler(SubpBody body) {
  result = body.getStmts().getExceptions().getChild(_)
}

/**
 * As `AvoidingNoReturn`, and not leaving the end of an exception handler of the body:
 * the paths on which the body's own statements complete normally.
 */
private module MainStatements implements PathReachability::ConfigSig {
  predicate isSource(ControlFlowNode n) { n instanceof ControlFlow::EntryNode }

  predicate isSink(ControlFlowNode n) { none() }

  predicate isBarrierEdge(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2) {
    AvoidingNoReturn::isBarrierEdge(n1, t, n2)
    or
    n1.isAfter(bodyHandler(_).getStmts()) and n2 = n1.getASuccessor(t)
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
 * Holds if the statements of `body` can complete normally, other than by completing
 * one of its exception handlers: a plain edge into the normal exit, which a `return`
 * reaches by a return edge instead.
 */
private predicate fallsOffEnd(SubpBody body) {
  exists(ControlFlowNode last, ControlFlow::NormalExitNode exit, DirectSuccessor t |
    last.getASuccessor(t) = exit and
    exit.getEnclosingCallable() = body and
    PathReachability::Make<MainStatements>::reached(last)
  )
}

/** Gets the last statement of `stmts`, pragmas left out, seen through a statement name. */
private Stmt lastStmt(StmtList stmts) {
  exists(Stmt s | s = max(Stmt t, int i | t = stmts.getChild(i) | t order by i) |
    result = s.(NamedStmt).getStmt()
    or
    not s instanceof NamedStmt and result = s
  )
}

/** Holds if call statement `s` does not return: its target is `No_Return` or raises. */
private predicate isNoReturnCallStmt(CallStmt s) {
  exists(Subprogram target | target = s.getCall().(Call).getTarget() |
    target.isNoReturn() or
    target.hasQualifiedName(["Ada.Exceptions.Raise_Exception", "Ada.Exceptions.Reraise_Occurrence"])
  )
  or
  isUnresolvedNoReturnCall(s)
}

/**
 * Holds if `stmts` ends with a statement that cannot complete normally, judged from the
 * syntax alone, as AdaControl's `Abnormal_Function_Return` does: a `return`, a `raise`, a
 * call that does not return, or a block, an `if` with an `else`, a `case`, or a plain
 * `loop` without an `exit` or `goto`, whose every branch ends so.
 */
private predicate endsAbnormally(StmtList stmts) {
  exists(Stmt last | last = lastStmt(stmts) |
    last instanceof ReturnStmt
    or
    last instanceof ExtendedReturnStmt
    or
    last instanceof RaiseStmt
    or
    isNoReturnCallStmt(last)
    or
    exists(HandledStmts hs |
      hs = [last.(BeginBlock).getStmts(), last.(DeclBlock).getStmts()] and
      endsAbnormally(hs.getStmts()) and
      forall(ExceptionHandler h | h = hs.getExceptions().getChild(_) | endsAbnormally(h.getStmts()))
    )
    or
    exists(IfStmt i |
      i = last and
      endsAbnormally(i.getThenStmts()) and
      endsAbnormally(i.getElsePart().getStmts()) and
      forall(ElsifStmtPart e | e = i.getAlternatives().getChild(_) | endsAbnormally(e.getStmts()))
    )
    or
    exists(CaseStmt c | c = last |
      forall(CaseStmtAlternative a | a = c.getAlternatives().getChild(_) |
        endsAbnormally(a.getStmts())
      )
    )
    or
    exists(LoopStmt l | l = last |
      not exists(ExitStmt e | e.getParent+() = l) and
      not exists(GotoStmt g | g.getParent+() = l)
    )
  )
}

/**
 * Holds if exception handler `h` of `body`'s statements can complete normally: control
 * then runs off the end of the function. Where the CFG reaches the handler, along a
 * feasible path to its end; elsewhere (the CFG raises only at calls and `raise`, so a
 * handler for `Constraint_Error` from `10 / X` has no nodes), by `endsAbnormally`.
 */
private predicate handlerFallsOffEnd(SubpBody body, ExceptionHandler h) {
  h = bodyHandler(body) and
  (
    exists(ControlFlowNode n | n.isAfter(h.getStmts()) and reachableAvoidingNoReturn(n, body))
    or
    not exists(ControlFlowNode n | n.isBefore(h)) and
    not endsAbnormally(h.getStmts())
  )
}

from AdaNode n, string msg
where
  exists(SubpBody body |
    body.getSubpSpec().getSubpKind() instanceof SubpKindFunction and
    body.fromSource()
  |
    fallsOffEnd(body) and
    n = body and
    msg =
      "This function may run off the end without executing a return statement, which raises Program_Error at run time."
    or
    handlerFallsOffEnd(body, n) and
    msg =
      "This exception handler may complete without a return or raise statement, which raises Program_Error at run time."
  )
select n, msg
