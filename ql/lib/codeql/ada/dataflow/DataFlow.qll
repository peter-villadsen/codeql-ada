/**
 * Global data flow for Ada: the entry point for queries (see `docs/dataflow-design.md`).
 *
 * `DataFlow::Global<Config>` finds value-preserving flow, within and across
 * subprograms; `TaintTracking.qll` adds derived-value steps on top.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.dataflow.internal.SsaImpl as SsaImpl
private import codeql.ada.dataflow.internal.DataFlowImpl as Impl
private import ada

module DataFlow {
  import Impl::AdaDataFlow

  /** A node in the data-flow graph: an expression, a formal parameter, or an SSA node. */
  class Node = Impl::AdaDataFlowInput::Node;

  /**
   * Gets the subprogram declaration `call` invokes, through any subprogram
   * renamings, if the callee resolves (D-021, D-026). Indexing, slicing and type
   * conversions, which parse like calls, have no result.
   */
  Raw::BasicDecl getCallTarget(Raw::Expr call) {
    result = SsaImpl::resolveSubpRenaming(SsaImpl::getCallTarget(call))
  }

  /**
   * Holds if `actual` is what `call` passes for the formal named `formal`
   * (case-insensitively), whether the association is positional or named. The
   * name is the formal's in the subprogram ultimately called, so a renaming that
   * renames its formals is seen through.
   */
  bindingset[formal]
  predicate isArgumentFor(Raw::Expr call, Raw::Expr actual, string formal) {
    exists(int idx |
      SsaImpl::callActual(call, actual, idx) and
      SsaImpl::formalNameAt(getCallTarget(call), idx) = formal.toLowerCase()
    )
  }
}
