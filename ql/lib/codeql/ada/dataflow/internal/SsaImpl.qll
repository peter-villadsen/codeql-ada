/**
 * Ada instantiation of the shared `codeql/ssa` framework (Phase 9.2, D-013's
 * sibling for SSA: see `docs/phase9.2-plan.md`).
 *
 * `codeql/ssa`'s `Make` module wants a `BB::CfgSig<Location>` (basic blocks with
 * a `ControlFlowNode` type) plus an `InputSig` giving `SourceVariable` and the
 * `variableWrite`/`variableRead` relations. The control-flow graph's basic blocks
 * (`Impl::Cfg`, from the shared `codeql/controlflow` library) are that `CfgSig`.
 *
 * `SsaInput` was filled in incrementally: `SourceVariable` in Task 9.2.2,
 * `variableWrite`/`variableRead` in Task 9.2.3. See `docs/phase9.2-plan.md` for
 * the design decisions behind each anchor choice and two real bugs (one in
 * `codeql/ssa`'s dead-store elision interacting with `out`/`in out`
 * parameters, one a `strictcount`-over-an-empty-range mistake of this file's
 * own) that testing against scratch databases surfaced and fixed.
 */

private import codeql.ssa.Ssa as SsaLib
private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl
private import ada
private import codeql.ada.internal.Formals as Formals
private import codeql.ada.internal.CallResolution as CallResolution

/** The basic blocks of the control-flow graph, which implement `codeql/ssa`'s `CfgSig`. */
private module SsaCfg = Impl::Cfg;

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
 * by construction (D-024). A package-level object may be referenced by an
 * expanded name (`Store.G`), and so may an enclosing subprogram's object
 * (`Outer.X`): such a reference is compared by its last identifier, and the
 * identifier inside it is not a reference of its own. The texts are compared
 * ignoring case, as Ada does: `X` may be declared `X` and referenced as `x`.
 * `p_referenced_defining_name` is the documented extractor-side fallback if a
 * case is found this cannot settle.
 */
SsaSourceVariable getSourceVariable(Name n) {
  exists(Raw::BasicDecl d |
    d = n.getReferencedDecl() and
    result = d.(BasicDecl).getADefiningName() and
    result.getName().(Name).getText().toLowerCase() = simpleNameText(n).toLowerCase() and
    not n = any(Raw::DottedName dn).getSuffix()
  )
}

/** Gets the text of `n`, or of its last identifier if it is an expanded name. */
private string simpleNameText(Name n) {
  result = n.(Raw::DottedName).getSuffix().(Name).getText()
  or
  not n instanceof Raw::DottedName and result = n.getText()
}

/**
 * Gets the position `(bb, i)` of the control-flow node that represents `astNode`
 * (`injects`): unique, as the graph is not split. No result if `astNode` is
 * unreachable.
 */
private predicate cfgPos(Raw::AdaNode astNode, SsaCfg::BasicBlock bb, int i) {
  exists(Impl::ControlFlowNode n | n.injects(astNode) | bb.getNode(i) = n)
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
  exists(Raw::ForLoopSpec spec |
    // a `for` loop's, or a quantified expression's (`for all E of V => ...`)
    (spec = any(Raw::ForLoopStmt s).getSpec() or spec = any(Raw::QuantifiedExpr q).getLoopSpec()) and
    v = spec.getVarDecl().(BasicDecl).getADefiningName() and
    nameNode = v and
    cfgPos(spec.getIterExpr(), bb, i)
  )
}

/**
 * Gets the `SubpSpec` of a callable declaration (`Formals::callableSpecOf`): also of a
 * generic subprogram, the target of a call to one of its instances.
 */
private Raw::SubpSpec getSubpSpecOf(Raw::BasicDecl d) { result = Formals::callableSpecOf(d) }

/**
 * Gets the `CfgScope` that formal parameter `ps` belongs to, if it is part of
 * a body's own parameter list (not a separate spec's -- that copy is never
 * entered, so it gets no entry write). Precise even for a nested subprogram's
 * parameter, unlike `AdaNode.getAnEnclosingBody()` (`ada.qll`), which
 * would also match an *outer* enclosing subprogram and so cannot be reused
 * here: `ps` is tied directly to the one `SubpSpec` it is part of, and from
 * there to the one scope whose own `getSubpSpec()` is that same node.
 */
private Impl::CfgScope paramOwningScope(Raw::ParamSpec ps) {
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
    bb.(SsaCfg::EntryBasicBlock).getScope() = paramOwningScope(ps) and
    i = 0
  )
}

/**
 * A write with no value at its scope's entry, for an object declared without an
 * initialiser (`R : Pair;`) and for an `out` formal. It stores nothing, so no value
 * flows from it; it exists so that a component or element stored before any whole
 * write (`R.A := X;`) is a store into a defined variable, whose post-update node then
 * reaches the next read of `R`.
 */
private predicate uninitializedWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  nameNode = v and
  i = 0 and
  (
    exists(Raw::ObjectDecl d |
      v = d.(BasicDecl).getADefiningName() and
      not exists(d.getDefaultExpr()) and
      not exists(d.getRenamingClause()) and
      bb.(SsaCfg::EntryBasicBlock).getScope() = Impl::getEnclosingCfgScope(d)
    )
    or
    exists(Raw::ParamSpec ps |
      v = ps.(BasicDecl).getADefiningName() and
      ps.getMode() instanceof Raw::ModeOut and
      bb.(SsaCfg::EntryBasicBlock).getScope() = paramOwningScope(ps)
    )
  )
}

/**
 * Gets the entry that `accept` statement or entry body `completion` completes: for an
 * `accept`, the entry of that name declared by the task whose body it is in (`accept`
 * names do not resolve, and a task body is matched to its declaration by qualified
 * name); for an entry body, the declaration it completes.
 */
Raw::BasicDecl completedEntry(Raw::AdaNode completion) {
  // an `accept` in the body of the task that declares the entry, by the entry's name
  exists(Raw::BasicDecl task, Raw::TaskBody taskBody |
    (task instanceof Raw::SingleTaskDecl or task instanceof Raw::TaskTypeDecl) and
    task.(BasicDecl).getQualifiedName() = taskBody.(BasicDecl).getQualifiedName() and
    completion.(Raw::AcceptStmt).getParent+() = taskBody and
    result.(Raw::EntryDecl).getParent+() = task and
    result.(Raw::EntryDecl).getSpec().getEntryName().getName().(Name).getText().toLowerCase() =
      completion.(Raw::AcceptStmt).getBodyDecl().getName().getName().(Name).getText().toLowerCase()
  )
  or
  ada_body_part(result, completion) and completion instanceof Raw::EntryBody
}

/** Gets the formal part of `accept` statement or entry body `completion`. */
private Raw::Params completionParams(Raw::AdaNode completion) {
  result = completion.(Raw::AcceptStmt).getParams().getParams()
  or
  result = completion.(Raw::EntryBody).getParams().getParams()
}

/**
 * Holds if `v` is the `idx`th formal of `accept` statement or entry body `completion`.
 */
predicate entryCompletionFormal(Raw::AdaNode completion, SsaSourceVariable v, int idx) {
  v = Formals::paramsFormalAt(completionParams(completion), idx) and
  exists(completedEntry(completion))
}

/**
 * A write of an entry's formal where the rendezvous begins: at the `accept`
 * statement's own node, or at an entry body's entry. Its value comes from the entry
 * call's actual (`jumpStep` in `DataFlowImpl.qll`), or, for an `out` formal, from
 * nowhere, like an uninitialised object.
 */
private predicate entryFormalWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  nameNode = v and
  exists(Raw::AdaNode completion | entryCompletionFormal(completion, v, _) |
    cfgPos(completion.(Raw::AcceptStmt), bb, i)
    or
    bb.(SsaCfg::EntryBasicBlock).getScope() = completion.(Raw::EntryBody) and
    i = 0
  )
}

/** Holds if `def` is the write of the `idx`th formal of `completion` (`entryFormalWrite`). */
predicate isEntryFormalDef(SsaImpl::WriteDefinition def, Raw::AdaNode completion, int idx) {
  exists(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v |
    def.definesAt(v, bb, i) and
    entryFormalWrite(bb, i, v, _) and
    entryCompletionFormal(completion, v, idx)
  )
}

/**
 * Holds if `actual` is what entry call `call` (`Worker.Put (X)`) passes for the
 * entry's `idx`th formal, by position or by name; `entry` is the entry called.
 */
predicate entryCallActual(Raw::CallExpr call, Raw::BasicDecl entry, Raw::Expr actual, int idx) {
  entry = call.getName().(Name).getReferencedDecl() and
  entry instanceof Raw::EntryDecl and
  cfgPos(call, _, _) and
  exists(Raw::Params params, Raw::ParamAssoc assoc |
    params = entry.(Raw::EntryDecl).getSpec().getEntryParams() and
    assoc = call.getSuffix().(Raw::AssocList).getChild(_) and
    actual = assoc.getRExpr()
  |
    not exists(assoc.getDesignator()) and idx = assoc.getParentIndex()
    or
    Formals::paramsFormalAt(params, idx).getName().(Name).getText().toLowerCase() =
      assoc.getDesignator().(Name).getText().toLowerCase()
  )
}

/** Gets the 0-based flattened formal index of `dn` among `spec`'s formals (`Formals::formalIndex`). */
private int formalIndex(Raw::SubpSpec spec, Raw::DefiningName dn) {
  result = Formals::formalIndex(spec, dn)
}

/** Gets the `i`th formal (0-based, flattened across `ParamSpec` groups) of `spec` (`Formals::formalAt`). */
private Raw::DefiningName formalAt(Raw::SubpSpec spec, int i) { result = Formals::formalAt(spec, i) }

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









/** Holds if `n` has a CFG node: data flow counts a call only where the CFG evaluates it. */
private predicate hasCfgNode(Raw::AdaNode n) { cfgPos(n, _, _) }

private module Resolution = CallResolution::Make<hasCfgNode/1, Formals::callableSpecOf/1>;

/**
 * Gets the declaration `call` invokes (`CallResolution::Make::getCallTarget`), for a
 * call that has a CFG node.
 */
Raw::BasicDecl getCallTarget(Raw::Expr call) { result = Resolution::getCallTarget(call) }

/** Holds if `call` is written in prefixed-view notation, `Obj.Op (Args)`. */
predicate isPrefixedViewCall(Raw::Expr call) { Resolution::isPrefixedViewCall(call) }

/**
 * Holds if `call` calls through access-to-subprogram value `receiver`
 * (`CallResolution::accessCallSpec`), and has a CFG node.
 */
predicate isAccessCall(Raw::Expr call, Raw::Expr receiver) {
  exists(CallResolution::accessCallSpec(call, receiver)) and hasCfgNode(call)
}

/**
 * Gets the `SubpSpec` of the subprogram `call` invokes (see `getCallTarget`), or, for a
 * call through an access-to-subprogram value, the access type's profile.
 */
Raw::SubpSpec getCalleeSpec(Raw::Expr call) {
  result = Resolution::getCalleeSpec(call)
  or
  isAccessCall(call, _) and result = CallResolution::accessCallSpec(call, _)
}

/** Holds if `actual` is what `call` passes for its callee's `idx`th formal. */
predicate callActual(Raw::Expr call, Raw::Expr actual, int idx) {
  Resolution::callActual(call, actual, idx)
  or
  isAccessCall(call, _) and CallResolution::accessCallActual(call, actual, idx)
}

/** Gets the subprogram `d` denotes once subprogram renamings are followed. */
Raw::BasicDecl resolveSubpRenaming(Raw::BasicDecl d) {
  result = CallResolution::resolveSubpRenaming(d)
}


/**
 * Gets the node whose CFG position represents "the call has now happened": the
 * wrapping `CallStmt`'s own node when `call` is a procedure-call statement (its node
 * follows the call's), or `call` itself otherwise.
 */
private Raw::AdaNode callEffectNode(Raw::Expr call) {
  exists(Raw::CallStmt cs | cs.getCall() = call | result = cs)
  or
  not exists(Raw::CallStmt cs | cs.getCall() = call) and result = call
}

/**
 * Holds if `v` is an `out`/`in out` formal parameter and `(bb, i)` is the
 * normal exit node of its owning scope.
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
  exists(Raw::ParamSpec ps, Raw::Mode mode, Impl::ControlFlow::NormalExitNode exitNode |
    v = ps.(BasicDecl).getADefiningName() and
    mode = ps.getMode() and
    (mode instanceof Raw::ModeOut or mode instanceof Raw::ModeInOut) and
    exitNode.getEnclosingCallable() = paramOwningScope(ps) and
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

/** Gets the CFG scope that evaluates `n`. */
private Impl::CfgScope nodeScope(Raw::AdaNode n) {
  exists(Impl::ControlFlowNode cn | cn.injects(n) | result = cn.getEnclosingCallable())
}

/**
 * Holds if `v` is referred to in scope `sc` and stored into in a different scope: a
 * package variable, or a variable shared between a subprogram and the subprograms
 * nested in it.
 */
private predicate writtenElsewhere(SsaSourceVariable v, Impl::CfgScope sc) {
  exists(Name n | v = getSourceVariable(n) and sc = nodeScope(n)) and
  exists(Raw::Expr value | variableStore(v, value) and not nodeScope(value) = sc)
}

/**
 * An uncertain write of `v` at each resolved call in a scope where `v` is written
 * elsewhere (`writtenElsewhere`): the callee may store into it, so a read after the
 * call need not see the value written before it.
 */
private predicate callMayWrite(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v) {
  exists(Raw::Expr call |
    exists(getCallTarget(call)) and
    cfgPos(callEffectNode(call), bb, i) and
    writtenElsewhere(v, bb.getScope())
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
      paramEntryWrite(bb, i, v, _) or
      uninitializedWrite(bb, i, v, _) or
      entryFormalWrite(bb, i, v, _)
    ) and
    certain = true
    or
    outOrInOutActualWrite(bb, i, v, _) and certain = false
    or
    callMayWrite(bb, i, v) and certain = false
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
 * Holds if the `i`th node of `bb` is a write of `v` that is written in the source, and
 * `nameNode` is where (see `getWriteNameOccurrence`): every certain write kind. The
 * uncertain ones (an `out` actual, a call that may store into `v`) are implicit.
 */
private predicate explicitWriteAt(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::AdaNode nameNode) {
  assignWrite(bb, i, v, nameNode) or
  objectDeclInitWrite(bb, i, v, nameNode) or
  forLoopVarWrite(bb, i, v, nameNode) or
  paramEntryWrite(bb, i, v, nameNode) or
  uninitializedWrite(bb, i, v, nameNode) or
  entryFormalWrite(bb, i, v, nameNode)
}

private newtype TVariableWrite = TWrite(Raw::Expr nameNode) { explicitWriteAt(_, _, _, nameNode) }

/**
 * A write to a variable written in the source: an assignment (`X := E`), an object
 * declaration, with or without an initialiser, a `for` loop's variable, or a formal
 * parameter's value on entry (including an entry's formal, at its `accept`).
 *
 * It is represented by the name written: the assignment's target, or the declaration's
 * defining name.
 */
class VariableWrite extends TVariableWrite {
  /** Gets the name being written: the assignment's target, or the defining name. */
  SsaExpr asExpr() { this = TWrite(result) }

  /**
   * Gets the expression with the value being written, if any: the assignment's
   * right-hand side, or the declaration's initialiser. A `for` loop variable takes the
   * elements of its iterable, not the iterable itself, so it has no value; nor has a
   * parameter, whose value comes from the caller.
   */
  SsaExpr getValue() {
    exists(Raw::AssignStmt s | this.asExpr() = s.getDest() | result = s.getExpr())
    or
    exists(Raw::ObjectDecl d |
      this.asExpr() = d.(BasicDecl).getADefiningName() and result = d.getDefaultExpr()
    )
  }

  /** Holds if this write is the value of parameter `p` on entry to its body. */
  predicate isParameterInit(Parameter p) {
    exists(Raw::AdaNode n | n = this.asExpr() |
      n = p.getADeclaration() and
      (paramEntryWrite(_, _, _, n) or uninitializedWrite(_, _, _, n))
    )
  }

  /** Gets a textual representation of this write. */
  string toString() { result = this.asExpr().toString() }

  /** Gets the location of this write. */
  Raw::Location getLocation() { result = this.asExpr().getLocation() }
}

/** An expression, with the control-flow node that evaluates it (see `cfgPos`). */
class SsaExpr extends Raw::Expr {
  /** Gets the control-flow node that evaluates this expression. */
  Impl::ControlFlowNode getControlFlowNode() { result.injects(this) }
}

private class ParameterAlias = Parameter;

private class VariableWriteAlias = VariableWrite;

private module SsaMakeInput implements SsaImpl::SsaInputSig {
  class Expr = SsaExpr;

  class Parameter = ParameterAlias;

  class VariableWrite = VariableWriteAlias;

  predicate explicitWrite(VariableWrite w, SsaCfg::BasicBlock bb, int i, SsaSourceVariable v) {
    explicitWriteAt(bb, i, v, w.asExpr())
  }
}

/**
 * The class-based SSA API (`SsaDefinition`, `SsaExplicitWrite`, `SsaParameterInit`,
 * `SsaPhiDefinition`, ...), with its predicates cached; public in `codeql.ada.dataflow.Ssa`.
 */
module Ssa = SsaImpl::MakeSsa<SsaMakeInput>;

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
    uninitializedWrite(bb, i, v, result) or
    entryFormalWrite(bb, i, v, result) or
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
      bb1.getLastNode().injects(this) and
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
predicate formalOf(SsaSourceVariable v, Impl::CfgScope c, int idx, Raw::Mode mode) {
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

/**
 * Holds if `value` is stored into variable `v` by an assignment (`V := value`) or by
 * `v`'s own initialiser. Used for flow between subprograms through a variable that
 * more than one of them refers to (`jumpStep`), where SSA, which works within one
 * subprogram, does not apply.
 */
predicate variableStore(SsaSourceVariable v, Raw::Expr value) {
  exists(Raw::AssignStmt s | v = getSourceVariable(s.getDest()) and value = s.getExpr())
  or
  exists(Raw::ObjectDecl d | v = d.(BasicDecl).getADefiningName() and value = d.getDefaultExpr())
}

/** Holds if `n` reads variable `v`: a reference that is neither an assignment target nor a designator. */
predicate variableReadRef(SsaSourceVariable v, Name n) {
  v = getSourceVariable(n) and
  not isAssignTarget(n) and
  not isDesignator(n) and
  cfgPos(n, _, _)
}

/**
 * Holds if the read `n` of `v` is reached by a certain write in its own subprogram, with
 * no other definition merging in: whatever other subprograms store into `v`, `n` sees
 * this write's value.
 */
predicate readOverwrittenLocally(SsaSourceVariable v, Name n) {
  exists(SsaCfg::BasicBlock bb, int i, SsaImpl::WriteDefinition def |
    variableReadRef(v, n) and
    cfgPos(n, bb, i) and
    SsaImpl::ssaDefReachesRead(v, def, bb, i) and
    not def instanceof SsaImpl::UncertainWriteDefinition
  )
}

/**
 * Holds if `def` is the write of a `for` loop's variable and `iterable` is what the
 * loop iterates over; `isOf` is `true` for `for E of V` (an element of `V`) and `false`
 * for `for C in V.Iterate` or a range (a value of the iterable itself).
 */
predicate forLoopDef(SsaImpl::WriteDefinition def, Raw::Expr iterable, boolean isOf) {
  exists(SsaCfg::BasicBlock bb, int i, SsaSourceVariable v, Raw::ForLoopSpec spec |
    def.definesAt(v, bb, i) and
    forLoopVarWrite(bb, i, v, _) and
    v = spec.getVarDecl().(BasicDecl).getADefiningName() and
    iterable = spec.getIterExpr() and
    if spec.getLoopType() instanceof Raw::IterTypeOf then isOf = true else isOf = false
  )
}
