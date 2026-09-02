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
 * `variableWrite`/`variableRead` in Task 9.2.3. Until the latter lands, the
 * relations hold `none()` so this module compiles and `SsaImpl` can be
 * referenced without producing SSA definitions.
 */

private import codeql.ssa.Ssa as SsaLib
private import codeql.controlflow.BasicBlock as BB
private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl
private import ada

/** The `CfgSig` adapter: renames `CfgImpl`'s node type into the shape `codeql/ssa` wants. */
private module SsaCfg implements BB::CfgSig<Raw::Location> {
  class ControlFlowNode = Impl::CfgImpl::Node;

  class BasicBlock = Impl::CfgImpl::BasicBlocks::BasicBlock;

  class EntryBasicBlock = Impl::CfgImpl::BasicBlocks::EntryBasicBlock;

  predicate dominatingEdge = Impl::CfgImpl::BasicBlocks::dominatingEdge/2;
}

/**
 * A local variable, parameter, or loop variable that SSA can track (D-024;
 * see `docs/phase9.2-plan.md` Task 9.2.2). Restricted to the `DefiningName`s
 * introduced by an `ObjectDecl`, `ParamSpec` or `ForLoopVarDecl` -- not record
 * components, array elements, dereferences, `NumberDecl`s (static; see the C-5
 * note in `BURNDOWN.md`) or renamings (`ObjectDecl.getRenamingClause()`; a
 * renaming is an alias for another object, not an independent variable).
 * `BasicDecl.getADefiningName()` (from `ada.qll`) already does the "one name
 * per introduced identifier, not per nested declaration" work generically
 * across all three shapes, so it is reused here rather than special-cased
 * per shape.
 *
 * Named `SsaSourceVariable` (not `SourceVariable`) at file scope only to avoid
 * colliding with `SsaInput`'s own required member of that name below, which
 * aliases it. External code should use `SsaImpl::SourceVariable` (or this
 * file's `getSourceVariable`, whose result type is this class) rather than
 * naming `SsaSourceVariable` directly.
 */
class SsaSourceVariable extends Raw::DefiningName {
  SsaSourceVariable() {
    exists(Raw::ObjectDecl d | this = d.(BasicDecl).getADefiningName())
    or
    exists(Raw::ParamSpec d | this = d.(BasicDecl).getADefiningName())
    or
    exists(Raw::ForLoopVarDecl d | this = d.(BasicDecl).getADefiningName())
  }

  override string toString() { result = this.getName().(Name).getText() }
}

/**
 * Gets the source variable that `n` refers to.
 *
 * `ada_xref` resolves a name to its `BasicDecl`, not to the specific
 * `DefiningName` within it, so a multi-identifier declaration such as
 * `X, Y : Integer` is ambiguous at that level. Narrowing by name text is
 * exact here because identifiers introduced by one declaration are distinct
 * by construction (D-024). Ada does not allow a local object, parameter or
 * loop variable to be referenced through a dotted (package-qualified) name
 * within its own scope, so `n` is always a plain reference for the
 * constructs `SsaSourceVariable` covers -- never itself a `DottedName`,
 * though `Name.getText()` is used regardless since it also handles that case
 * uniformly. `p_referenced_defining_name` is the documented extractor-side
 * fallback if a case is found this cannot settle.
 */
SsaSourceVariable getSourceVariable(Name n) {
  exists(Raw::BasicDecl d |
    d = n.getReferencedDecl() and
    result = d.(BasicDecl).getADefiningName() and
    result.getName().(Name).getText() = n.getText()
  )
}

/** The `InputSig` implementation consumed by `SsaLib::Make`. Writes/reads land in Task 9.2.3. */
private module SsaInput implements SsaLib::InputSig<Raw::Location, SsaCfg::BasicBlock> {
  class SourceVariable = SsaSourceVariable;

  predicate variableWrite(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    none()
  }

  predicate variableRead(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    none()
  }
}

/** The Ada SSA implementation. */
module SsaImpl = SsaLib::Make<Raw::Location, SsaCfg, SsaInput>;
