/**
 * Provides `MissingPairedCall`, a parameterized module for the general
 * "call to `Foo` not invariably followed by a call to `Bar`" pattern (e.g.
 * `Open` without `Close`, `Seize` without `Release`) -- the query the Ada
 * CFG (Phase 7) was built for.
 *
 * See `docs/query-writing.md` for a worked example of instantiating this
 * module for a user-supplied pair of calls.
 */

import ControlFlowGraph
private import codeql.ada.ast.internal.Raw

signature predicate isFirstCallSig(Raw::AdaNode call);

signature predicate isSecondCallSig(Raw::AdaNode call);

/**
 * Finds calls matching `first` after which some control-flow path can reach
 * the end of the enclosing scope without passing through a call matching
 * `second`.
 */
module MissingPairedCall<isFirstCallSig/1 first, isSecondCallSig/1 second> {
  private predicate isSecond(ControlFlowNode n) { second(any(Raw::AdaNode a | n.injects(a))) }

  /**
   * Holds if `n` can reach its scope's exit node without passing through a
   * `second` call, considering every CFG edge, including exceptional
   * (raise) ones.
   */
  private predicate reachesExitStrict(ControlFlowNode n) {
    n instanceof ControlFlow::ExitNode
    or
    exists(ControlFlowNode succ | succ = n.getASuccessor() |
      not isSecond(succ) and reachesExitStrict(succ)
    )
  }

  /** As `reachesExitStrict`, but only following non-exceptional edges. */
  private predicate reachesExitNormalOnly(ControlFlowNode n) {
    n instanceof ControlFlow::ExitNode
    or
    exists(ControlFlowNode succ, SuccessorType t | succ = n.getASuccessor(t) |
      not t instanceof ExceptionSuccessor and
      not isSecond(succ) and
      reachesExitNormalOnly(succ)
    )
  }

  /**
   * A `first` call after which some CFG path -- including exceptional
   * (raise) edges -- reaches the end of the enclosing scope without passing
   * through a `second` call. This is the conservative variant: an
   * intervening call that might raise before reaching `second` still counts
   * as "invariably followed", since the exceptional path is also checked.
   */
  predicate missingPairedCallStrict(Raw::AdaNode call) {
    first(call) and
    exists(ControlFlowNode n | n.injects(call) | reachesExitStrict(n))
  }

  /**
   * As `missingPairedCallStrict`, but ignoring exceptional (raise) edges.
   * Higher signal-to-noise: a path that only reaches the scope exit by
   * first raising an exception is not reported. Recommended default for
   * new queries (see `OpenWithoutClose.ql`).
   */
  predicate missingPairedCallNormalPathsOnly(Raw::AdaNode call) {
    first(call) and
    exists(ControlFlowNode n | n.injects(call) | reachesExitNormalOnly(n))
  }
}
