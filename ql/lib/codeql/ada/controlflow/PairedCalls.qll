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
private import codeql.ada.controlflow.PathReachability
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
   * Paths from a `first` call to its scope's exit that do not pass through a `second`
   * call, considering every CFG edge, including exceptional (raise) ones. They are the
   * feasible paths through `finally` parts (`PathReachability`): a `finally` part's end
   * continues only the way it was entered.
   */
  private module StrictConfig implements PathReachability::ConfigSig {
    predicate isSource(ControlFlowNode n) { first(any(Raw::AdaNode a | n.injects(a))) }

    predicate isSink(ControlFlowNode n) { n instanceof ControlFlow::ExitNode }

    predicate isBarrier(ControlFlowNode n) { isSecond(n) }
  }

  /** As `StrictConfig`, but only following non-exceptional edges. */
  private module NormalOnlyConfig implements PathReachability::ConfigSig {
    predicate isSource = StrictConfig::isSource/1;

    predicate isSink = StrictConfig::isSink/1;

    predicate isBarrier = StrictConfig::isBarrier/1;

    predicate isBarrierEdge(ControlFlowNode n1, SuccessorType t, ControlFlowNode n2) {
      t instanceof ExceptionSuccessor and exists(n1) and exists(n2)
    }
  }

  private predicate reachesExitStrict(ControlFlowNode n) {
    PathReachability::Make<StrictConfig>::reaches(n, _)
  }

  private predicate reachesExitNormalOnly(ControlFlowNode n) {
    PathReachability::Make<NormalOnlyConfig>::reaches(n, _)
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
