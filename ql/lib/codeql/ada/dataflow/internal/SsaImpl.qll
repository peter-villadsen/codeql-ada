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
 * `SsaInput` was filled in incrementally: `SourceVariable` in Task 9.2.2,
 * `variableWrite`/`variableRead` in Task 9.2.3. See `docs/phase9.2-plan.md` for
 * the design decisions behind each anchor choice and two real bugs (one in
 * `codeql/ssa`'s dead-store elision interacting with `out`/`in out`
 * parameters, one a `strictcount`-over-an-empty-range mistake of this file's
 * own) that testing against scratch databases surfaced and fixed.
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
 * uniformly. The texts are compared ignoring case, as Ada does: `X` may be
 * declared `X` and referenced as `x`. `p_referenced_defining_name` is the
 * documented extractor-side fallback if a case is found this cannot settle.
 */
SsaSourceVariable getSourceVariable(Name n) {
  exists(Raw::BasicDecl d |
    d = n.getReferencedDecl() and
    result = d.(BasicDecl).getADefiningName() and
    result.getName().(Name).getText().toLowerCase() = n.getText().toLowerCase()
  )
}

/**
 * Gets the position `(bb, i)` of `astNode`'s control-flow node -- unique,
 * since this project's `Make` instantiation (`ControlFlowGraphImpl.qll`) does
 * not use CFG splitting, so an `AstCfgNode` maps to at most one node per AST
 * element. No result if `astNode` is unreachable.
 */
private predicate cfgPos(Raw::AdaNode astNode, SsaCfg::BasicBlock bb, int i) {
  exists(Impl::CfgImpl::AstCfgNode n | n.getAstNode() = astNode | bb.getNode(i) = n)
}

/** Holds if `n` is the target of an assignment -- a write, never a read. */
private predicate isAssignTarget(Name n) { n = any(Raw::AssignStmt s).getDest() }

/**
 * Holds if `n` is a named association's designator (`X` in `Foo (X => Y)`) --
 * a syntactic label identifying which formal an actual binds to, not a value
 * reference, even though `ada_xref` resolves it (to the formal's own
 * `ParamSpec`) and `GenericPostOrderTree` evaluates it like any other
 * `Identifier` (the CFG's node-kind classification does not distinguish a
 * designator's *role* from an ordinary reference; see `docs/cfg-design.md`'s
 * coverage appendix, whose "designators" bullet is a different node kind, not
 * this one). Found by the renamed-source debug tool (`ql/debug/
 * PrintSsaRenamed.ql`, `docs/ssa-design.md`): without this exclusion, a call
 * with a named association registers a spurious read of the *callee's*
 * formal, positioned in the *caller's* basic blocks -- harmless to the actual
 * `Definition`/phi graph (that scope has no write of the callee's formal for
 * any dominance-frontier or liveness computation to act on, so nothing is
 * ever inserted incorrectly), but genuinely wrong, and something a future
 * consumer that iterates reads for reporting (a path-problem query, say)
 * would otherwise show.
 */
private predicate isDesignator(Name n) { n = any(Raw::ParamAssoc pa).getDesignator() }

/**
 * A write to the assignment's target, at the `AssignStmt`'s own node (its
 * post-order self-node, evaluated after both the RHS and the target -- see
 * `AssignStmtTree`). Only fires when the target is itself a `SourceVariable`
 * reference: a complex target (`Arr (I) := ...`, `Rec.Field := ...`) has no
 * result from `getSourceVariable`, so no whole-variable write is claimed for
 * it -- sub-element writes are out of scope for v1 (D-023), and this falls
 * out of `getSourceVariable`'s own restriction rather than needing a
 * separate check here.
 *
 * `nameNode` is the target reference itself -- not the same as this write's
 * CFG anchor `(bb, i)` (the whole `AssignStmt`), but where the variable's
 * name actually appears in the source. Carried through only for
 * `getWriteNameOccurrence` (a debug-tooling accessor, see its own doc); every
 * other caller ignores it.
 */
private predicate assignWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Name nameNode) {
  exists(Raw::AssignStmt s |
    nameNode = s.getDest() and
    v = getSourceVariable(nameNode) and
    cfgPos(s, bb, i)
  )
}

/**
 * A write from an `ObjectDecl`'s initialiser, at the initialiser expression's
 * own node -- `ObjectDecl` itself never gets a CFG node ("structural" in the
 * coverage appendix; the C-1 fix made `BodyTree`/`DeclBlockTree` elaborate the
 * initialiser directly), so its own top expression node is the only anchor.
 * `X, Y : Integer := F (1);` writes both `X` and `Y` at the same position,
 * from the one shared initialiser -- correct, since Ada evaluates it once and
 * assigns the (copied) result to each name.
 *
 * `nameNode` is `v` itself: for a declaration-based write, the `SourceVariable`
 * already *is* the `DefiningName` to render (unlike `assignWrite`, there is no
 * separate reference node). See `assignWrite`'s doc for why this column
 * exists.
 */
private predicate objectDeclInitWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  exists(Raw::ObjectDecl d, Raw::Expr e |
    e = d.getDefaultExpr() and
    v = d.(BasicDecl).getADefiningName() and
    nameNode = v and
    cfgPos(e, bb, i)
  )
}

/**
 * A write to a `for` loop's variable, at the position of the loop's iterable
 * expression -- `ForLoopVarDecl` and `ForLoopSpec` are both "n/a" in the
 * coverage appendix (no CFG node of their own: `ForLoopStmtTree` evaluates the
 * iterable once, then jumps straight into the body on each iteration, with no
 * per-iteration node representing "the variable takes its next value"). This
 * is a deliberate approximation, not a gap this task can close: SSA does not
 * need one write per dynamic iteration, only a static definition that
 * dominates every read inside the body (which the iterable's node does,
 * including across the back edge) and a value origin a later taint step can
 * use (the iterable itself -- taint into the iterated collection should reach
 * the loop variable).
 *
 * `nameNode` is `v` itself, same reasoning as `objectDeclInitWrite`.
 */
private predicate forLoopVarWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  exists(Raw::ForLoopStmt s, Raw::ForLoopSpec spec |
    spec = s.getSpec() and
    v = spec.getVarDecl().(BasicDecl).getADefiningName() and
    nameNode = v and
    cfgPos(spec.getIterExpr(), bb, i)
  )
}

/**
 * Gets the `SubpSpec` of a callable declaration -- the shapes Task 9.2.3
 * resolves calls to (functions and procedures only; entries, protected
 * operations and generic instantiations are unresolved in v1, D-023).
 */
private Raw::SubpSpec getSubpSpecOf(Raw::BasicDecl d) {
  result = d.(Raw::ClassicSubpDecl).getSubpSpec()
  or
  result = d.(Raw::BaseSubpBody).getSubpSpec()
  or
  // a separate body's stub (`procedure P is separate;`), the declaration when there
  // is no other; `ada_body_part` pairs it with the subunit's body
  result = d.(Raw::SubpBodyStub).getSubpSpec()
}

/**
 * Gets the `CfgScope` that formal parameter `ps` belongs to, if it is part of
 * a body's own parameter list (not a separate spec's -- that copy is never
 * entered, so it gets no entry write). Precise even for a nested subprogram's
 * parameter, unlike `AdaNode.getEnclosingSubprogram()` (`ada.qll`), which
 * would also match an *outer* enclosing subprogram and so cannot be reused
 * here: `ps` is tied directly to the one `SubpSpec` it is part of, and from
 * there to the one scope whose own `getSubpSpec()` is that same node.
 */
private Impl::Scopes::CfgScope paramOwningScope(Raw::ParamSpec ps) {
  exists(Raw::SubpSpec spec |
    ps = spec.getSubpParams().getParams().getChild(_) and
    result.(Raw::BaseSubpBody).getSubpSpec() = spec
  )
}

/**
 * Holds if `ps` receives an incoming value from the caller: mode `in`
 * (`ModeDefault` included -- that is what an unwritten mode means) or
 * `in out`. A pure `out` formal receives nothing at entry -- Ada leaves it
 * exactly as uninitialised as a local object with no initialiser, which gets
 * no write either (see `paramEntryWrite`'s doc) -- by the same reasoning.
 */
private predicate receivesArgument(Raw::ParamSpec ps) {
  ps.getMode() instanceof Raw::ModeIn or
  ps.getMode() instanceof Raw::ModeDefault or
  ps.getMode() instanceof Raw::ModeInOut
}

/**
 * A write to a parameter's initial value, at its owning scope's entry node.
 * `ParamSpec` never gets its own CFG node ("n/a" in the coverage appendix;
 * entry jumps straight to the body's first real node), so the scope's entry
 * node -- index 0 of its `EntryBasicBlock`, by that class's own definition --
 * is the only anchor, matching the `SsaParameterInit` convention `codeql/ssa`
 * documents for exactly this case (a write co-located with scope entry).
 *
 * A pure `out` formal is deliberately excluded (`receivesArgument`): like an
 * uninitialised local, it gets no write here at all, relying on the SSA
 * framework to correctly report "no reaching definition" for a read that
 * precedes the first explicit write inside the body -- not on a synthetic
 * placeholder write with an undefined value.
 *
 * `nameNode` is `v` itself, same reasoning as `objectDeclInitWrite`.
 */
private predicate paramEntryWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  exists(Raw::ParamSpec ps |
    v = ps.(BasicDecl).getADefiningName() and
    nameNode = v and
    receivesArgument(ps) and
    bb.(Impl::CfgImpl::BasicBlocks::EntryBasicBlock).getScope() = paramOwningScope(ps) and
    i = 0
  )
}

/**
 * Gets any formal parameter's defining name, from any `ParamSpec` group, of
 * `spec` -- flattened across groups, since Ada allows one group to declare
 * several names sharing a mode and type (`A, B : in out Integer`), and
 * positional argument matching counts each name, not each group.
 */
private Raw::DefiningName anyFormalName(Raw::SubpSpec spec) {
  result = spec.getSubpParams().getParams().getChild(_).(Raw::ParamSpec).getIds().getChild(_)
}

/**
 * Gets a sort key placing `dn` -- one of `spec`'s formals, see `anyFormalName`
 * -- in formal-parameter order: group index, then id-within-group index, each
 * read off `dn`'s own position among its siblings (`getParentIndex()`) rather
 * than by inverting `getChild` (which needs its index argument already
 * bound).
 */
private int formalKey(Raw::SubpSpec spec, Raw::DefiningName dn) {
  exists(Raw::ParamSpec ps |
    dn = anyFormalName(spec) and
    dn = ps.getIds().getChild(_) and
    ps = spec.getSubpParams().getParams().getChild(_) and
    result = ps.getParentIndex() * 1000 + dn.getParentIndex()
  )
}

/**
 * Gets the 0-based flattened formal index of `dn` among `spec`'s formals (see
 * `formalKey`). `count`, not `strictcount`: the first formal has nothing
 * preceding it, an empty range, and `strictcount` -- unlike `count` -- has no
 * result at all over an empty range, which silently dropped the first formal
 * of every `SubpSpec` (confirmed empirically: only the second of two formals
 * ever showed up, see `docs/phase9.2-plan.md` Task 9.2.3).
 */
private int formalIndex(Raw::SubpSpec spec, Raw::DefiningName dn) {
  dn = anyFormalName(spec) and
  result =
    count(Raw::DefiningName other |
      other = anyFormalName(spec) and formalKey(spec, other) < formalKey(spec, dn)
    )
}

/** Gets the `i`th formal (0-based, flattened across `ParamSpec` groups -- see `anyFormalName`) of `spec`. */
private Raw::DefiningName formalAt(Raw::SubpSpec spec, int i) { i = formalIndex(spec, result) }

/**
 * Gets the name, lower-cased, of the `i`th formal (see `formalAt`) of subprogram
 * declaration `d`.
 */
string formalNameAt(Raw::BasicDecl d, int i) {
  result = formalAt(getSubpSpecOf(d), i).getName().(Name).getText().toLowerCase()
}

/** Gets the mode of the `i`th formal of `spec` (see `formalAt`). */
private Raw::Mode formalMode(Raw::SubpSpec spec, int i) {
  exists(Raw::DefiningName dn, Raw::ParamSpec ps |
    dn = formalAt(spec, i) and
    dn.getParent().getParent() = ps and
    result = ps.getMode()
  )
}

/** Gets the 0-based formal index of `spec`'s formal whose name, lower-cased, is `lname` (Ada ignores case). */
private int formalIndexNamed(Raw::SubpSpec spec, string lname) {
  exists(Raw::DefiningName dn |
    dn = formalAt(spec, result) and
    dn.getName().(Name).getText().toLowerCase() = lname
  )
}

/**
 * Holds if `p`, the prefix of a dotted name, is an expanded name's prefix -- it
 * names the unit the suffix is declared in (`Pkg.Foo`, or `Outer.Foo` for a
 * subprogram declared inside `Outer`) -- rather than an object whose type the
 * suffix is an operation of (a prefixed view, `Obj.Op`). Any package-like prefix
 * counts, since a renamed package does not contain its own declarations; any other
 * prefix counts only if the suffix is declared inside it or its body.
 */
private predicate isExpandedNamePrefix(Raw::Name p) {
  exists(Raw::DottedName dn, Raw::BasicDecl pd | p = dn.getPrefix() and pd = p.(Name).getReferencedDecl() |
    pd instanceof Raw::BasePackageDecl or
    pd instanceof Raw::PackageBody or
    pd instanceof Raw::PackageRenamingDecl or
    pd instanceof Raw::GenericPackageDecl or
    pd instanceof Raw::GenericPackageInstantiation or
    pd instanceof Raw::GenericPackageRenamingDecl or
    dn.getSuffix().(Name).getReferencedDecl().getParent+() = [pd, pd.(BasicDecl).getBody()]
  )
}

/**
 * Gets the name that `call` invokes its subprogram through: a `CallExpr`'s name,
 * or `call` itself for a call written without parentheses (`X := Get;`,
 * `Obj.Op;`). A bare name is a call only where it is evaluated (it has a CFG
 * node, which excludes `end` names, renamed names and default expressions), and
 * not where it is the callee part of a larger name: a `CallExpr`'s name, a dotted
 * name's suffix, an expanded name's prefix, an attribute's prefix (`F'Access`) or
 * a named association's designator.
 */
private Raw::Name calleeName(Raw::Expr call) {
  result = call.(Raw::CallExpr).getName() and cfgPos(call, _, _)
  or
  result = call and
  not call instanceof Raw::CallExpr and
  not call = any(Raw::CallExpr c).getName() and
  not call = any(Raw::DottedName d).getSuffix() and
  not isExpandedNamePrefix(call) and
  not call = any(Raw::AttributeRef a).getPrefix() and
  not isDesignator(call) and
  cfgPos(call, _, _)
}

/**
 * Holds if `call` is written in prefixed-view (dot) notation, `Obj.Op (Args)`:
 * `Obj` is then its first actual. Recognised by a dotted callee whose prefix is not
 * an expanded name's and has a type, i.e. denotes a value.
 */
predicate isPrefixedViewCall(Raw::Expr call) {
  exists(Raw::DottedName dn | dn = calleeName(call) |
    not isExpandedNamePrefix(dn.getPrefix()) and
    exists(dn.getPrefix().(Expr).getType()) and
    // a protected operation's prefix is the protected object, never a formal
    not isProtectedOperation(dn.getSuffix().(Name).getReferencedDecl())
  )
}

/** Holds if `d` is declared in a protected type or object (`protected Box is ...`). */
private predicate isProtectedOperation(Raw::BasicDecl d) {
  d.getParent+() instanceof Raw::ProtectedDef
}

/**
 * Gets the declaration `call` invokes: a subprogram with a `SubpSpec` of its own,
 * resolved through `ada_xref` (`Name.getReferencedDecl()`, D-021), never by name
 * text. Libadalang parses indexing, slicing and type conversion as a `CallExpr`
 * too; those resolve to an object or a type, so they have no result here, and
 * neither do calls to generic instantiations, entries and access values
 * (docs/dataflow-design.md, D-023). A subprogram renaming is a result -- it is a
 * `BaseSubpBody` with a `SubpSpec` of its own, whose formals bind the actuals --
 * and `resolveSubpRenaming` takes it on to the subprogram it renames. A protected
 * operation (`PO.Op (X)`) is a call whose prefix is the protected object, not a
 * formal, so its actuals bind as written. A dotted callee that is neither an
 * expanded name, a recognisable prefixed view nor a protected operation is left out,
 * since its actuals cannot be matched to formals.
 *
 * An operator application (`UnOp`, `BinOp`) is a call when its operator resolves to a
 * user-written subprogram (`function "+" (L, R : T) return T`, or a renaming of one).
 * Predefined operators do not resolve (D-026) and stay plain expressions.
 * Like a named call, it counts only where it is evaluated: not in a type or range
 * declaration, which has no CFG node.
 */
Raw::BasicDecl getCallTarget(Raw::Expr call) {
  exists(Raw::Name callee | callee = calleeName(call) |
    result = callee.(Name).getReferencedDecl() and
    exists(getSubpSpecOf(result)) and
    (
      not callee instanceof Raw::DottedName
      or
      isExpandedNamePrefix(callee.(Raw::DottedName).getPrefix())
      or
      isPrefixedViewCall(call)
      or
      // `PO.Op (X)`: the prefix is the protected object, the actuals bind as written
      isProtectedOperation(result)
    )
  )
  or
  // only where the operator is evaluated (has a CFG node), as for named calls
  cfgPos(call, _, _) and
  result = operatorOf(call).(Name).getReferencedDecl() and
  exists(getSubpSpecOf(result))
}

/** Gets the operator node of operator application `call`. */
private Raw::Op operatorOf(Raw::Expr call) {
  result = call.(Raw::UnOp).getOp() or result = call.(Raw::BinOp).getOp()
}

/**
 * Gets the subprogram that `d` denotes once subprogram renamings are followed: `d`
 * itself if it is not a renaming. A renaming conforms to what it renames in the
 * number, order and modes of its formals, so an actual bound through the renaming's
 * own spec binds the same position in the target. No result for a renaming of a
 * prefixed view (`renames Obj.Op`, whose target has one formal more) or of anything
 * that does not resolve to a subprogram (an attribute, an entry, an instantiation).
 */
Raw::BasicDecl resolveSubpRenaming(Raw::BasicDecl d) {
  not d instanceof Raw::SubpRenamingDecl and result = d
  or
  exists(Raw::Name n | n = d.(Raw::SubpRenamingDecl).getRenames().getRenamedObject() |
    (not n instanceof Raw::DottedName or isExpandedNamePrefix(n.(Raw::DottedName).getPrefix())) and
    result = resolveSubpRenaming(n.(Name).getReferencedDecl()) and
    exists(getSubpSpecOf(result))
  )
}

/** Gets the `SubpSpec` of the subprogram `call` invokes (see `getCallTarget`). */
Raw::SubpSpec getCalleeSpec(Raw::Expr call) { result = getSubpSpecOf(getCallTarget(call)) }

/**
 * Holds if `actual` is the actual that `call` passes for its callee's `idx`th formal
 * (0-based, flattened, see `formalAt`). A named association (`X => Y`) binds by
 * designator. A positional one binds by its own source position, since Ada requires
 * every positional association to precede every named one -- shifted by one in a
 * prefixed-view call, whose prefix is the first actual. Formals left to their
 * default have no actual.
 */
predicate callActual(Raw::Expr call, Raw::Expr actual, int idx) {
  exists(Raw::SubpSpec spec | spec = getCalleeSpec(call) |
    exists(Raw::ParamAssoc assoc |
      assoc = call.(Raw::CallExpr).getSuffix().(Raw::AssocList).getChild(_) and
      actual = assoc.getRExpr()
    |
      not exists(assoc.getDesignator()) and
      (if isPrefixedViewCall(call) then idx = assoc.getParentIndex() + 1 else idx = assoc.getParentIndex())
      or
      idx = formalIndexNamed(spec, assoc.getDesignator().(Name).getText().toLowerCase())
    )
    or
    isPrefixedViewCall(call) and
    actual = calleeName(call).(Raw::DottedName).getPrefix() and
    idx = 0
  )
  or
  // an operator application: the operands, by position (operators take no named actuals)
  exists(getCalleeSpec(call)) and
  (
    actual = call.(Raw::UnOp).getExpr() and idx = 0
    or
    actual = call.(Raw::BinOp).getLeft() and idx = 0
    or
    actual = call.(Raw::BinOp).getRight() and idx = 1
  )
}

/**
 * Gets the node whose CFG position represents "the call has now happened": the
 * wrapping `CallStmt`'s own node when `call` is a procedure-call statement (its own
 * node follows the call's, per `CallStmtTree`), or `call` itself otherwise.
 */
private Raw::AdaNode callEffectNode(Raw::Expr call) {
  exists(Raw::CallStmt cs | cs.getCall() = call | result = cs)
  or
  not exists(Raw::CallStmt cs | cs.getCall() = call) and result = call
}

/**
 * Holds if `v` is an `out`/`in out` formal parameter and `(bb, i)` is a
 * normal-completion `AnnotatedExitNode` of its owning scope.
 *
 * `codeql/ssa`'s own `TWriteDef` construction requires a write to be followed
 * by a live read before it becomes a `Definition` at all (correct dead-store
 * elision for a genuinely-unused local -- confirmed empirically: a plain
 * local written but never read produces no `Definition`, see
 * `docs/phase9.2-plan.md` Task 9.2.3). An `out`/`in out` parameter's *last*
 * write is never really dead -- the caller reads it back when the call
 * returns -- but with nothing modelling that read, it would silently vanish
 * from the SSA universe before Task 9.4 ever gets a chance to model the
 * return flow. This synthetic read at the scope's own normal exit is what
 * keeps it alive; `getAnUltimateDefinition()` from that read is exactly what
 * Task 9.4's `out`/`in out` return-flow step needs.
 */
private predicate outOrInOutParamExitRead(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v) {
  exists(Raw::ParamSpec ps, Raw::Mode mode, Impl::CfgImpl::AnnotatedExitNode exitNode |
    v = ps.(BasicDecl).getADefiningName() and
    mode = ps.getMode() and
    (mode instanceof Raw::ModeOut or mode instanceof Raw::ModeInOut) and
    exitNode.getScope() = paramOwningScope(ps) and
    exitNode.isNormal() and
    bb.getNode(i) = exitNode
  )
}

/**
 * Holds if `v` is the return object of extended return statement `return R : T do ...
 * end return` and `(bb, i)` is the statement's own node, where the function returns
 * `R`. A synthetic read there keeps `R`'s last write alive and gives Task 9.4 a
 * return node for it, as `outOrInOutParamExitRead` does for `out` formals.
 */
private predicate extendedReturnRead(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v) {
  exists(Raw::ExtendedReturnStmt s |
    v = s.getDecl().(BasicDecl).getADefiningName() and
    cfgPos(s, bb, i)
  )
}

/**
 * An uncertain write (D-022) to an actual passed as an `out`/`in out` formal
 * of a resolved call: the callee may or may not actually update it, which is
 * exactly what the shared SSA framework's `certain` flag exists to express.
 * The actual's own reference is *also* a normal read (from the generic rule
 * in `variableRead`, since argument evaluation walks it like any other
 * expression) -- a harmless, conservative approximation for a pure `out`
 * actual, which Ada does not really read, and the accurate behaviour for
 * `in out`, which it does.
 *
 * `nameNode` is the actual argument reference itself -- not the same as this
 * write's CFG anchor `(bb, i)` (the call's effect node), same reasoning as
 * `assignWrite`'s `nameNode`. Unlike the other four write kinds, this one
 * *does* coincide with a genuine reference occurrence rather than a
 * declaration, so it doubles as `variableRead`'s generic "any reference is a
 * read" occurrence for the same node -- see this predicate's own doc above.
 */
private predicate outOrInOutActualWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Name nameNode) {
  outOrInOutActualWriteAt(bb, i, v, nameNode, _, _)
}

/** Like `outOrInOutActualWrite`, also giving the `call` and the formal index `idx` written back. */
private predicate outOrInOutActualWriteAt(
  SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Name nameNode, Raw::Expr call, int idx
) {
  exists(Raw::Mode mode |
    callActual(call, nameNode, idx) and
    mode = formalMode(getCalleeSpec(call), idx) and
    (mode instanceof Raw::ModeOut or mode instanceof Raw::ModeInOut) and
    v = getSourceVariable(nameNode) and
    cfgPos(callEffectNode(call), bb, i)
  )
}

/** The `InputSig` implementation consumed by `SsaLib::Make`. */
private module SsaInput implements SsaLib::InputSig<Raw::Location, SsaCfg::BasicBlock> {
  class SourceVariable = SsaSourceVariable;

  predicate variableWrite(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    (
      assignWrite(bb, i, v, _) or
      objectDeclInitWrite(bb, i, v, _) or
      forLoopVarWrite(bb, i, v, _) or
      paramEntryWrite(bb, i, v, _)
    ) and
    certain = true
    or
    outOrInOutActualWrite(bb, i, v, _) and certain = false
  }

  predicate variableRead(SsaCfg::BasicBlock bb, int i, SourceVariable v, boolean certain) {
    (
      exists(Name n |
        v = getSourceVariable(n) and
        not isAssignTarget(n) and
        not isDesignator(n) and
        cfgPos(n, bb, i)
      )
      or
      outOrInOutParamExitRead(bb, i, v)
      or
      extendedReturnRead(bb, i, v)
    ) and
    certain = true
  }
}

/** The Ada SSA implementation. */
module SsaImpl = SsaLib::Make<Raw::Location, SsaCfg, SsaInput>;

/**
 * Gets the AST node whose text represents write `wd` in the source -- as
 * opposed to `wd`'s own `getLocation()`, which is its CFG anchor and, for
 * every write kind except a call-site `out`/`in out` actual, a different
 * point entirely (see each write predicate's own doc comment above for why).
 *
 * Built for the SSA-renamed-source debug tool (`ql/debug/PrintSsaRenamed.ql`,
 * `docs/ssa-design.md` "Renamed-source rendering"); has no effect on the SSA
 * graph itself, and exists only so that tool has one place to ask "where do
 * I print this write's subscript" without re-deriving the write-kind
 * classification independently (and risking it drifting from the real
 * logic above).
 */
Raw::AdaNode getWriteNameOccurrence(SsaImpl::WriteDefinition wd) {
  exists(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v | wd.definesAt(v, bb, i) |
    assignWrite(bb, i, v, result) or
    objectDeclInitWrite(bb, i, v, result) or
    forLoopVarWrite(bb, i, v, result) or
    paramEntryWrite(bb, i, v, result) or
    outOrInOutActualWrite(bb, i, v, result)
  )
}

/**
 * Gets the expression whose value write definition `def` stores: an assignment's
 * right-hand side, or an object declaration's initialiser. No result for the other
 * write kinds, which have no local source expression -- a parameter's entry write
 * (its value comes from the caller, Task 9.4), an `out`/`in out` actual's uncertain
 * write (from the callee, Task 9.4), and a `for` loop variable, whose value is an
 * element of the iterable, not the iterable itself (a taint step at most, never a
 * value step).
 */
Raw::Expr getWrittenValue(SsaImpl::WriteDefinition def) {
  exists(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v | def.definesAt(v, bb, i) |
    exists(Raw::AssignStmt s | assignWrite(bb, i, v, _) and cfgPos(s, bb, i) | result = s.getExpr())
    or
    objectDeclInitWrite(bb, i, v, _) and cfgPos(result, bb, i)
  )
}

private newtype TDfExpr =
  TAstExpr(Raw::Expr e) { cfgPos(e, _, _) } or
  TParamExitRead(SsaSourceVariable v) { outOrInOutParamExitRead(_, _, v) } or
  TExtendedReturnRead(SsaSourceVariable v) { extendedReturnRead(_, _, v) }

/**
 * An expression as `DataFlowIntegration` sees it: an Ada expression with a CFG node,
 * the synthetic read of an `out`/`in out` formal at its scope's normal exit
 * (`outOrInOutParamExitRead`), or the synthetic read of an extended return's object
 * (`extendedReturnRead`). `DataFlowIntegration` only creates data-flow nodes
 * for reads that are expressions, and that read is the value the caller gets back
 * (D-022), so Task 9.4 needs a node for it: its return node. It is one per formal,
 * not one per exit node, so that two formals written back by one scope stay apart.
 */
class DfExpr extends TDfExpr {
  /** Gets the Ada expression this is, if it is not an exit read. */
  Raw::Expr asExpr() { this = TAstExpr(result) }

  /** Gets the `out`/`in out` formal this is the exit read of, if it is one. */
  SsaSourceVariable asParamExitRead() { this = TParamExitRead(result) }

  /** Gets the return object this is the read of, at its extended return statement. */
  SsaSourceVariable asExtendedReturnRead() { this = TExtendedReturnRead(result) }

  /** Gets a textual representation of this expression. */
  string toString() {
    result = this.asExpr().toString()
    or
    result = "[exit] " + this.asParamExitRead().toString()
    or
    result = "[return] " + this.asExtendedReturnRead().toString()
  }

  /** Holds if the `i`th node of basic block `bb` evaluates this expression. */
  predicate hasCfgNode(SsaCfg::BasicBlock bb, int i) {
    cfgPos(this.asExpr(), bb, i)
    or
    outOrInOutParamExitRead(bb, i, this.asParamExitRead())
    or
    extendedReturnRead(bb, i, this.asExtendedReturnRead())
  }
}

/**
 * The input to `codeql/ssa`'s `DataFlowIntegration` (Task 9.3), which builds the SSA
 * part of the local data-flow graph: nodes for definitions, phis and reads, and the
 * steps between them.
 *
 * Guards are implemented, not stubbed (decided in Task 9.3, see
 * `docs/dataflow-design.md`): a guard is any expression whose CFG node ends a basic
 * block with `BooleanSuccessor` edges -- a condition, or an operand of a
 * short-circuit operator -- which gives `BarrierGuard` support
 * (`if Is_Safe (X) then ... X ...`).
 */
module SsaDataFlowInput implements SsaImpl::DataFlowIntegrationInputSig {
  private import codeql.controlflow.SuccessorType
  private import codeql.util.Boolean

  class Expr = DfExpr;

  /**
   * Flow into an uncertain write -- an actual passed as an `out`/`in out` formal --
   * is allowed: the callee may leave the variable unchanged (D-022), so its previous
   * value may survive the call.
   */
  predicate allowFlowIntoUncertainDef(SsaImpl::UncertainWriteDefinition def) { any() }

  class GuardValue = Boolean;

  class Guard extends Raw::Expr {
    /** Holds if evaluating this guard to `val` takes the CFG edge `bb1 -> bb2`. */
    predicate hasValueBranchEdge(SsaCfg::BasicBlock bb1, SsaCfg::BasicBlock bb2, GuardValue val) {
      bb1.getLastNode().(Impl::CfgImpl::AstCfgNode).getAstNode() = this and
      bb2 = bb1.getASuccessor(any(BooleanSuccessor s | s.getValue() = val))
    }

    predicate valueControlsBranchEdge(SsaCfg::BasicBlock bb1, SsaCfg::BasicBlock bb2, GuardValue val) {
      this.hasValueBranchEdge(bb1, bb2, val)
    }
  }

  predicate guardDirectlyControlsBlock(Guard guard, SsaCfg::BasicBlock bb, GuardValue val) {
    exists(SsaCfg::BasicBlock bb1, SsaCfg::BasicBlock bb2 |
      guard.hasValueBranchEdge(bb1, bb2, val) and
      SsaCfg::dominatingEdge(bb1, bb2) and
      bb2.dominates(bb)
    )
  }
}

/** The SSA part of the local data-flow graph (Task 9.3); see `LocalFlow.qll`. */
module SsaFlow = SsaImpl::DataFlowIntegration<SsaDataFlowInput>;

/**
 * Gets the formal parameter `v`'s owning scope `c`, its 0-based flattened position
 * `idx` (see `formalAt`) and its `mode`, for a formal of a body with its own CFG --
 * the formals Task 9.4's parameter and return nodes are built for.
 */
predicate formalOf(SsaSourceVariable v, Impl::Scopes::CfgScope c, int idx, Raw::Mode mode) {
  exists(Raw::ParamSpec ps |
    v = ps.(BasicDecl).getADefiningName() and
    c = paramOwningScope(ps) and
    idx = formalIndex(c.(Raw::BaseSubpBody).getSubpSpec(), v) and
    mode = ps.getMode()
  )
}

/** Holds if formal `v` receives a value from the caller: mode `in` or `in out`. */
predicate formalReceivesArgument(SsaSourceVariable v) {
  exists(Raw::ParamSpec ps | v = ps.(BasicDecl).getADefiningName() and receivesArgument(ps))
}

/** Holds if `def` is formal `v`'s entry write, the value the caller passed. */
predicate isParameterEntryDef(SsaImpl::WriteDefinition def, SsaSourceVariable v) {
  exists(SsaCfg::BasicBlock bb, int i | def.definesAt(v, bb, i) and paramEntryWrite(bb, i, v, _))
}

/**
 * Holds if `def` is the uncertain write-back of `call`'s actual for its `idx`th
 * formal, an `out`/`in out` one (D-022).
 */
predicate isOutActualDef(SsaImpl::WriteDefinition def, Raw::Expr call, int idx) {
  exists(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v |
    def.definesAt(v, bb, i) and outOrInOutActualWriteAt(bb, i, v, _, call, idx)
  )
}
