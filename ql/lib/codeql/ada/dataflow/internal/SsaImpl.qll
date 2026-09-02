/**
 * Ada instantiation of the shared `codeql/ssa` framework (Phase 9.2, D-013's
 * sibling for SSA: see `docs/phase9.2-plan.md`).
 *
 * `codeql/ssa`'s `Make` module wants a `BB::CfgSig<Location>` (basic blocks with
 * a `ControlFlowNode` type) plus an `InputSig` giving `SourceVariable` and the
 * `variableWrite`/`variableRead` relations. The Phase 7 CFG's own
 * `CfgImpl::BasicBlocks` nested module satisfies most of `CfgSig` already (it is
 * literally the shared `codeql/controlflow` framework's basic-block
 * construction) but does not export `ControlFlowNode` under that name, so
 * `SsaCfg` below is a thin renaming adapter, not a reimplementation.
 *
 * `SsaInput` is filled in incrementally: `SourceVariable` in Task 9.2.2,
 * `variableWrite`/`variableRead` in Task 9.2.3. Until then it holds `none()`
 * placeholders so this module compiles and `SsaImpl` can be referenced (Task
 * 9.2.1's acceptance criterion) without producing SSA definitions.
 */

private import codeql.ssa.Ssa as SsaLib
private import codeql.controlflow.BasicBlock as BB
private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl

/** The `CfgSig` adapter: renames `CfgImpl`'s node type into the shape `codeql/ssa` wants. */
private module SsaCfg implements BB::CfgSig<Raw::Location> {
  class ControlFlowNode = Impl::CfgImpl::Node;

  class BasicBlock = Impl::CfgImpl::BasicBlocks::BasicBlock;

  class EntryBasicBlock = Impl::CfgImpl::BasicBlocks::EntryBasicBlock;

  predicate dominatingEdge = Impl::CfgImpl::BasicBlocks::dominatingEdge/2;
}

/** The `InputSig` implementation consumed by `SsaLib::Make`. Placeholder pending 9.2.2/9.2.3. */
private module SsaInput implements SsaLib::InputSig<Raw::Location, SsaCfg::BasicBlock> {
  class SourceVariable extends Raw::DefiningName {
    SourceVariable() { none() }

    override string toString() { none() }
  }

  predicate variableWrite(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    none()
  }

  predicate variableRead(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    none()
  }
}

/** The Ada SSA implementation. */
module SsaImpl = SsaLib::Make<Raw::Location, SsaCfg, SsaInput>;
