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
   * Holds if `call` invokes the subprogram whose fully qualified name is
   * `qualifiedName` (case-insensitively), e.g. `"My_App.Shell.Run"`. Renamings and
   * `use` clauses are seen through. Every overload of that name matches.
   */
  bindingset[qualifiedName]
  predicate isCallTo(Raw::Expr call, string qualifiedName) {
    getCallTarget(call).(BasicDecl).hasQualifiedName(qualifiedName)
  }

  /** Gets an actual that `call` passes, for any formal, positional or named. */
  Raw::Expr getAnArgument(Raw::Expr call) { SsaImpl::callActual(call, result, _) }

  /**
   * Holds if `actual` is what `call` passes for its callee's `idx`th formal
   * (0-based, counting each name of a grouped `A, B : T` separately).
   */
  predicate isArgumentAt(Raw::Expr call, Raw::Expr actual, int idx) {
    SsaImpl::callActual(call, actual, idx)
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

  /**
   * Holds if `n` is a formal parameter (mode `in` or `in out`) of the subprogram
   * whose fully qualified name is `qualifiedName`, as it receives the caller's value:
   * the way to say "treat this subprogram's inputs as untrusted".
   */
  bindingset[qualifiedName]
  predicate isParameterOf(Node n, string qualifiedName) {
    exists(Raw::BaseSubpBody body | SsaImpl::formalOf(n.asParameter(), body, _, _) |
      body.(BasicDecl).hasQualifiedName(qualifiedName)
    )
  }
}
