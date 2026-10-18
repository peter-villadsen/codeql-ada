/**
 * Provides reachability along the control-flow graph's *feasible* paths through GNAT
 * `finally` parts.
 *
 * The graph does not split a `finally` part (D-029): its end continues every way the
 * part was entered, so it also contains paths that enter by `return` and continue as if
 * the sequence had completed normally, or enter normally and leave by the `return`.
 * `PathReachability::Make` follows only the paths on which a `finally` part continues
 * the way it was entered — normally, by `return`, by an exception, by an `exit` or by a
 * `goto` — by keeping, along a path, the way each enclosing `finally` part was entered.
 * A `finally` part's own `raise` or `return` may leave it whichever way it was entered.
 *
 * This is for path questions with no variable to follow ("does every path from this
 * call reach a call to `Close`?", "can this body complete normally?"). A question about
 * a variable's value along paths uses the shared `ControlFlowReachability` library, as
 * CodeQL for Java's `NullMaybe.ql` does; it handles `finally` parts too, but tracks only
 * whether each was entered abruptly, which does not tell the end of a `finally` part
 * continuing a `return` from one continuing normally (D-035).
 *
 * ```ql
 * module NoClose implements PathReachability::ConfigSig {
 *   predicate isSource(ControlFlowNode n) { n.injects(any(OpenCall c)) }
 *   predicate isSink(ControlFlowNode n) { n instanceof ControlFlow::ExitNode }
 *   predicate isBarrier(ControlFlowNode n) { n.injects(any(CloseCall c)) }
 * }
 *
 * from ControlFlowNode open
 * where PathReachability::Make<NoClose>::reaches(open, _)
 * select open, "Not closed on some path."
 * ```
 */

import ControlFlowGraph
private import codeql.ada.ast.internal.Raw

module PathReachability {
  /** Gets the statements of the GNAT `finally` part of a handled sequence. */
  private Raw::StmtList finallyPart() { result = any(Raw::HandledStmts hs).getFinallyPart().getStmts() }

  /** Holds if `n` is in `finally` part `fin`, at any depth. */
  private predicate inFinally(ControlFlowNode n, Raw::StmtList fin) {
    fin = finallyPart() and n.getAstNode().getParent*() = fin
  }

  /** Gets the number of `finally` parts `n` is in. */
  private int depth(ControlFlowNode n) { result = count(Raw::StmtList fin | inFinally(n, fin)) }

  private int maxDepth() { result = max([0, max(ControlFlowNode n | | depth(n))]) }

  /** Gets the way an edge of type `t` enters or leaves a `finally` part. */
  private string kindOf(SuccessorType t) {
    t instanceof NormalSuccessor and result = "normal"
    or
    t instanceof ReturnSuccessor and result = "return"
    or
    t instanceof ExceptionSuccessor and result = "exception"
    or
    t instanceof BreakSuccessor and result = "exit"
    or
    t instanceof GotoSuccessor and result = "goto"
  }

  private newtype TStack =
    TNil() or
    TCons(string kind, TStack tail) {
      kind = ["normal", "return", "exception", "exit", "goto"] and
      stackLength(tail) < maxDepth()
    }

  private int stackLength(TStack s) {
    s = TNil() and result = 0
    or
    exists(TStack tail | s = TCons(_, tail) and result = 1 + stackLength(tail))
  }

  /** The ways the `finally` parts around a node were entered, innermost first. */
  private class Stack extends TStack {
    string toString() {
      this = TNil() and result = ""
      or
      exists(string k, Stack tail | this = TCons(k, tail) and result = k + ";" + tail)
    }

    int length() { result = stackLength(this) }

    string top() { this = TCons(result, _) }

    Stack pop() { this = TCons(_, result) }
  }

  /** Gets the innermost `finally` part `n` is in. */
  private Raw::StmtList innermost(ControlFlowNode n) {
    inFinally(n, result) and
    not exists(Raw::StmtList inner | inFinally(n, inner) and inner.getParent+() = result)
  }

  /**
   * Holds if the edge `n1 -[t]-> n2` is feasible from the stack `s1` at `n1`, leaving
   * the stack `s2` at `n2`.
   */
  bindingset[s1]
  private predicate stepStack(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2, Stack s1, Stack s2) {
    exists(int d1, int d2 | d1 = depth(n1) and d2 = depth(n2) and n2 = n1.getASuccessor(t) |
      // within the same `finally` parts
      d2 = d1 and
      s2 = s1
      or
      // entering a `finally` part (always at its start: one at a time)
      d2 = d1 + 1 and
      s2 = TCons(kindOf(t), s1)
      or
      // leaving one or more: from the end of the innermost, only the way it was entered;
      // from within it (its own `raise` or `return`), any way
      d2 < d1 and
      s2 = popN(s1, d1 - d2) and
      (
        n1.isAfter(innermost(n1)) and s1.top() = kindOf(t)
        or
        not n1.isAfter(innermost(n1))
      )
    )
  }

  /** Gets `s` with its `n` innermost entries popped. */
  private Stack popN(Stack s, int n) {
    n = 0 and result = s
    or
    n in [1 .. maxDepth()] and result = popN(s.pop(), n - 1)
  }

  /** A reachability question: from a source, avoiding barriers, to a sink. */
  signature module ConfigSig {
    /** Holds if paths start at `n`. */
    predicate isSource(ControlFlowNode n);

    /** Holds if paths end at `n`. */
    predicate isSink(ControlFlowNode n);

    /** Holds if no path goes through `n` (other than starting there). */
    default predicate isBarrier(ControlFlowNode n) { none() }

    /** Holds if no path takes the edge `n1 -[t]-> n2`. */
    default predicate isBarrierEdge(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2) {
      none()
    }
  }

  /** Reachability along feasible paths for configuration `Config`. */
  module Make<ConfigSig Config> {
    /** Holds if a feasible path from `source` reaches `n` with the `finally` stack `s`. */
    private predicate reach(ControlFlowNode source, ControlFlowNode n, Stack s) {
      Config::isSource(source) and
      n = source and
      // where the source is inside `finally` parts, any way of entering them
      s.length() = depth(source)
      or
      exists(ControlFlowNode mid, Stack s0, SuccessorType t |
        reach(source, mid, s0) and
        not (Config::isSink(mid) and mid != source) and
        stepStack(mid, t, n, s0, s) and
        not Config::isBarrierEdge(mid, t, n) and
        not Config::isBarrier(n)
      )
    }

    /** Holds if a feasible path from `source` reaches `sink`, avoiding barriers. */
    predicate reaches(ControlFlowNode source, ControlFlowNode sink) {
      reach(source, sink, _) and Config::isSink(sink)
    }

    /** Holds if a feasible path from a source reaches `n`, avoiding barriers. */
    predicate reached(ControlFlowNode n) { reach(_, n, _) }
  }
}
