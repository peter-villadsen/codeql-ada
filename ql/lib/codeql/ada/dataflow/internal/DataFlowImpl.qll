/**
 * Cross-procedure data flow for Ada: Task 9.4, see `docs/dataflow-design.md`.
 *
 * Implements `codeql/dataflow`'s `InputSig` over the local graph of Task 9.3
 * (`LocalFlow.qll`) and instantiates the shared global analysis as `AdaDataFlow`.
 * The parts that carry design are the call graph (`viableCallable`, through
 * `ada_body_part`, D-021), argument/parameter matching by position *and* by name,
 * and the two kinds of return: a function's result and the write-back of each
 * `out`/`in out` formal (D-022). Everything else -- content (field) flow, types,
 * lambdas, unreachability in a call context -- is deliberately minimal in v1, each
 * a named limitation in the design document (D-023).
 */

private import codeql.dataflow.DataFlow as DF
private import codeql.util.Unit
private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl
private import codeql.ada.dataflow.internal.SsaImpl
private import codeql.ada.dataflow.internal.LocalFlow as LF
private import codeql.ada.dataflow.internal.Content as C
private import codeql.ada.internal.CallResolution as CallResolution
private import ada

/** Gets the scope of the CFG node that evaluates `e`. */
private Impl::Scopes::CfgScope exprScope(Raw::Expr e) {
  exists(Impl::CfgImpl::AstCfgNode n | n.getAstNode() = e | result = n.getScope())
}

/** Gets the basic block that SSA data-flow node `n` belongs to. */
private Impl::CfgImpl::BasicBlocks::BasicBlock ssaNodeBlock(SsaFlow::Node n) {
  result = n.(SsaFlow::SsaNode).getBasicBlock()
  or
  result = n.(SsaFlow::WriteDefSourceNode).getDefinition().getBasicBlock()
  or
  n.(SsaFlow::ExprNodePreOrPost).getExpr().hasCfgNode(result, _)
}

private newtype TReturnKind =
  TNormalReturnKind() or
  TOutReturnKind(int idx) {
    exists(Raw::Mode m | formalOf(_, _, idx, m) | m instanceof Raw::ModeOut or m instanceof Raw::ModeInOut)
  }

private newtype TDataFlowType = TUnitType()

private newtype TVoid = TNoValue() { none() }

/** An empty class, for the members of the signature v1 does not model. */
private class Void extends TVoid {
  string toString() { none() }
}

/** Gets `d`'s completion, or `d` itself; only a result that is a CFG scope survives. */
private Impl::Scopes::CfgScope bodyOf(Raw::BasicDecl d) { result = [d.(BasicDecl).getCompletion(), d] }

/** Holds if `n` is `T'Class`. */
private predicate isClassAttribute(Raw::Name n) {
  n.(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "class"
}

/** Holds if `te` is `T'Class`, or names an access type to `T'Class`. */
private predicate isClassWideTypeExpr(Raw::TypeExpr te) {
  exists(Raw::Name n | n = te.(Raw::SubtypeIndication).getName() |
    isClassAttribute(n)
    or
    isClassAttribute(n.getReferencedDecl()
          .(Raw::TypeDecl)
          .getTypeDef()
          .(Raw::TypeAccessDef)
          .getSubtypeIndication()
          .getName())
  )
  or
  // an anonymous access type, `access T'Class`
  isClassAttribute(te.(Raw::AnonymousType).getTypeDecl().getTypeDef().(Raw::TypeAccessDef).getSubtypeIndication().getName())
}

/**
 * Holds if `e` is class-wide, or designates a class-wide object: its type is `T'Class`,
 * it is a conversion to one (`Shape'Class (S)`), or it names an object or parameter
 * declared with such a type (`S : Shape'Class`, `P : access Shape'Class`).
 */
private predicate isClassWide(Raw::Expr e) {
  exists(Raw::BaseTypeDecl t | ada_expr_type(e, t) | t instanceof Raw::ClasswideTypeDecl)
  or
  isClassAttribute(e.(Raw::CallExpr).getName())
  or
  isClassWideTypeExpr(e.(Name).getReferencedDecl().(Raw::ParamSpec).getTypeExpr())
  or
  isClassWideTypeExpr(e.(Name).getReferencedDecl().(Raw::ObjectDecl).getTypeExpr())
  or
  isClassWide(e.(Raw::ParenExpr).getExpr())
  or
  isClassWide(e.(Raw::ExplicitDeref).getPrefix())
}

/**
 * Holds if `call` dispatches: its static target is a primitive operation of a tagged
 * type, and the actual for a parameter controlling it is class-wide. Such a call may run
 * the target or any override of it (`Subprogram.overrides`).
 */
private predicate isDispatchingCall(Raw::Expr call, Subprogram target) {
  target.getADeclaration() = resolveSubpRenaming(getCallTarget(call)) and
  exists(int i, Raw::Expr actual |
    target.isPrimitiveOf(_, i) and
    callActual(call, actual, i) and
    isClassWide(actual)
  )
}

/** A 0-based formal position (see `formalOf` and `callActual`). */
private class Position extends int {
  Position() { formalOf(_, _, this, _) or callActual(_, _, this) }
}

/** The `codeql/dataflow` language input for Ada. */
module AdaDataFlowInput implements DF::InputSig<Raw::Location> {
  class Node = LF::Node;

  /** A formal parameter receiving the caller's value: mode `in` or `in out`. */
  class ParameterNode extends Node {
    ParameterNode() { exists(this.asParameter()) }
  }

  /** An actual passed by a resolved call, positional, named or a prefixed-view prefix. */
  class ArgumentNode extends Node {
    ArgumentNode() { callActual(_, this.asExpr(), _) }
  }

  /**
   * A value leaving a callable: a function's `return` expression or expression-function
   * body (`TNormalReturnKind`), or the exit read of an `out`/`in out` formal
   * (`TOutReturnKind`, one per formal position, D-022). An extended return statement
   * (`return R : T do ... end return`) returns its object `R`, read at the statement.
   */
  class ReturnNode extends Node {
    private ReturnKind kind;

    ReturnNode() {
      kind = TNormalReturnKind() and
      (
        this.asExpr() = any(Raw::ReturnStmt r).getReturnExpr()
        or
        this.asExpr() = any(Raw::ExprFunction f).getExpr()
        or
        // the object of an extended return statement, read where the statement returns it
        exists(this.asSsaNode().(SsaFlow::ExprNode).getExpr().asExtendedReturnRead())
      )
      or
      exists(SsaSourceVariable v, int idx |
        v = this.asSsaNode().(SsaFlow::ExprNode).getExpr().asParamExitRead() and
        formalOf(v, _, idx, _) and
        kind = TOutReturnKind(idx)
      )
    }

    ReturnKind getKind() { result = kind }
  }

  /**
   * Holds if `n` receives the value `call` returns with `kind`: the call expression
   * itself for a function result, or the uncertain write-back of the `idx`th actual
   * for an `out`/`in out` formal (the source of that write's SSA definition).
   */
  private predicate outNode(Node n, DataFlowCall call, ReturnKind kind) {
    kind = TNormalReturnKind() and n.asExpr() = call
    or
    exists(SsaFlow::WriteDefSourceNode w, int idx |
      isOutActualDef(w.getDefinition(), call, idx) and
      kind = TOutReturnKind(idx) and
      n = LF::fromSsa(w)
    )
  }

  class OutNode extends Node {
    OutNode() { outNode(this, _, _) }
  }

  /**
   * The object after a store into one of its components or elements (`R` in
   * `R.A := X`), and, from the SSA layer, every variable read after the read.
   */
  class PostUpdateNode extends Node {
    PostUpdateNode() { exists(this.asPostUpdateOf()) }

    Node getPreUpdateNode() { result.asExpr() = this.asPostUpdateOf() }
  }

  class CastNode extends Node {
    CastNode() { none() }
  }

  predicate isParameterNode(ParameterNode p, DataFlowCallable c, ParameterPosition pos) {
    formalOf(p.asParameter(), c, pos, _)
  }

  predicate isArgumentNode(ArgumentNode n, DataFlowCall call, ArgumentPosition pos) {
    callActual(call, n.asExpr(), pos)
  }

  DataFlowCallable nodeGetEnclosingCallable(Node node) {
    result = exprScope(node.asExpr())
    or
    formalOf(node.asParameter(), result, _, _)
    or
    result = ssaNodeBlock(node.asSsaNode()).getScope()
    or
    result = exprScope(node.(LF::Node).asPostUpdateOf()) and not exists(node.asSsaNode())
  }

  DataFlowType getNodeType(Node node) { exists(node) and result = TUnitType() }

  /**
   * Hides the SSA layer's bookkeeping nodes (definitions, phis, write sources, exit
   * reads) from path explanations, except an `out`/`in out` write-back: that is the
   * hop where a value re-enters the caller, and a path should show it.
   */
  predicate nodeIsHidden(Node node) {
    exists(node.asSsaNode()) and not node instanceof OutNode and not node instanceof PostUpdateNode
  }

  class DataFlowExpr = Raw::Expr;

  Node exprNode(DataFlowExpr e) { result.asExpr() = e }

  /**
   * A call with a resolvable target declaration (`getCallTarget`), written with or
   * without parentheses, or a call through an access-to-subprogram value, whose
   * targets come from `lambdaCreation`.
   */
  class DataFlowCall extends Raw::Expr {
    DataFlowCall() { exists(getCallTarget(this)) or isAccessCall(this, _) }

    DataFlowCallable getEnclosingCallable() { result = exprScope(this) }
  }

  /** A CFG scope: a subprogram body, expression function, task body, entry body or package body. */
  class DataFlowCallable = Impl::Scopes::CfgScope;

  class ReturnKind extends TReturnKind {
    string toString() {
      this = TNormalReturnKind() and result = "return"
      or
      exists(int idx | this = TOutReturnKind(idx) | result = "out " + idx)
    }
  }

  /**
   * Gets the body `c` invokes (D-021): the target declaration -- through any
   * renamings, `resolveSubpRenaming` -- then its `ada_body_part` completion, or the
   * declaration itself when it is a body with no separate declaration. A completion
   * that is itself a renaming (renaming-as-body) is followed the same way once. A
   * target with neither -- an imported or abstract subprogram, a null procedure (no
   * CFG), a runtime subprogram, a separate body's stub -- gives no result, so the
   * call is visibly unresolved rather than guessed at.
   */
  DataFlowCallable viableCallable(DataFlowCall c) {
    exists(Raw::BasicDecl d | d = resolveSubpRenaming(getCallTarget(c)) |
      result = bodyOf(d) or result = bodyOf(resolveSubpRenaming(d.(BasicDecl).getCompletion()))
    )
    or
    // a dispatching call may run any override of its static target
    exists(Subprogram target | isDispatchingCall(c, target) |
      result = target.getAnOverride().getBody()
    )
  }

  OutNode getAnOutNode(DataFlowCall call, ReturnKind kind) { outNode(result, call, kind) }

  /** A single type (D-023): no type-based pruning in v1. */
  class DataFlowType extends TDataFlowType {
    string toString() { result = "" }
  }

  predicate compatibleTypes(DataFlowType t1, DataFlowType t2) { any() }

  predicate typeStrongerThan(DataFlowType t1, DataFlowType t2) { none() }

  /** A record component, or the elements of an array (`Content.qll`). */
  class Content = C::Content;

  predicate forceHighPrecision(Content c) { none() }

  /** A single content: stores and reads name one component, or the elements. */
  class ContentSet extends Content {
    Content getAStoreContent() { result = this }

    Content getAReadContent() { result = this }
  }

  class ContentApprox = Content;

  ContentApprox getContentApprox(Content c) { result = c }

  /** A 0-based formal position, flattened across `ParamSpec` groups. */
  class ParameterPosition = Position;

  /** The formal position an actual binds to, by position or by name. */
  class ArgumentPosition = Position;

  predicate parameterMatch(ParameterPosition ppos, ArgumentPosition apos) { ppos = apos }

  predicate simpleLocalFlowStep(Node node1, Node node2, string model) {
    LF::localFlowStep(node1, node2) and model = ""
    or
    // a cursor stands for its container (`Content.qll`)
    C::containerCursorStep(node1.asExpr(), node2.asExpr()) and model = ""
    or
    // `for C in V.Iterate`: the loop variable is a value of the iterable
    exists(SsaFlow::WriteDefSourceNode w, Raw::Expr iterable |
      forLoopDef(w.getDefinition(), iterable, false) and
      not iterable.(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot and
      node1.asExpr() = iterable and
      node2 = LF::fromSsa(w)
    ) and
    model = ""
  }

  /**
   * Flow through a variable between subprograms: from a value stored into a package
   * variable, or into a variable of an enclosing subprogram, to a read of it in a
   * different subprogram. SSA tracks a variable within one subprogram only, so this
   * step is flow-insensitive: any store reaches any read elsewhere, whatever the
   * order of the calls -- except a read that a certain write in its own subprogram
   * reaches (`V := 0; ... V ...`), which sees only that write.
   *
   * An entry call's actuals also jump, to the formals of each `accept` statement and
   * entry body for the entry: values passed in only, not `out` formals passed back.
   */
  predicate jumpStep(Node node1, Node node2) {
    // an entry call's actual to the formal of an `accept` statement or entry body
    // for that entry: a rendezvous is not a call the shared library can follow
    exists(Raw::Expr call, Raw::BasicDecl entry, int idx, Raw::AdaNode completion,
      SsaFlow::WriteDefSourceNode w |
      entryCallActual(call, entry, node1.asExpr(), idx) and
      entry = completedEntry(completion) and
      isEntryFormalDef(w.getDefinition(), completion, idx) and
      node2 = LF::fromSsa(w)
    )
    or
    exists(SsaSourceVariable v, Raw::Expr value, Name read |
      variableStore(v, value) and
      variableReadRef(v, read) and
      node1.asExpr() = value and
      node2.asExpr() = read and
      not exprScope(value) = exprScope(read) and
      not readOverwrittenLocally(v, read)
    )
  }

  /** A component access `R.F`, or indexing `V (I)`, reads the content from the prefix. */
  predicate readStep(Node node1, ContentSet c, Node node2) {
    exists(Raw::Expr e, Raw::Expr prefix |
      C::contentAccess(e, prefix, c) and
      node1.asExpr() = prefix and
      node2.asExpr() = e
    )
    or
    c.isElement() and
    (
      C::containerRead(node2.asExpr(), node1.asExpr())
      or
      // `for E of V`: the loop variable is an element of `V`
      exists(SsaFlow::WriteDefSourceNode w |
        forLoopDef(w.getDefinition(), node1.asExpr(), true) and
        node2 = LF::fromSsa(w)
      )
    )
  }

  /**
   * A store into a component or element (`R.F := X`, `V (I) := X`) stores the value
   * into the updated object's post-update node, and a store into a nested one
   * (`R.P.A := X`) stores that post-update node in turn into its own prefix's. An
   * aggregate stores each associated value, and a container operation (`Append`) its
   * new element.
   */
  predicate storeStep(Node node1, ContentSet c, Node node2) {
    exists(Raw::Expr t, Raw::Expr prefix |
      C::isStoreTarget(t) and
      C::contentAccess(t, prefix, c) and
      node2 = LF::postUpdateOf(prefix)
    |
      node1.asExpr() = any(Raw::AssignStmt s | s.getDest() = t).getExpr()
      or
      node1 = LF::postUpdateOf(t)
    )
    or
    exists(Raw::BaseAggregate agg, Raw::Expr value |
      C::aggregateStore(agg, value, c) and
      node1.asExpr() = value and
      node2.asExpr() = agg
    )
    or
    // a container operation stores into the write-back of its `in out` container
    exists(Raw::Expr call, Raw::Expr value, int idx, SsaFlow::WriteDefSourceNode w |
      C::containerStore(call, value, idx) and
      c.isElement() and
      node1.asExpr() = value and
      isOutActualDef(w.getDefinition(), call, idx) and
      node2 = LF::fromSsa(w)
    )
  }

  predicate clearsContent(Node n, ContentSet c) { none() }

  predicate expectsContent(Node n, ContentSet c) { none() }

  class NodeRegion extends Void {
    predicate contains(Node n) { none() }
  }

  predicate isUnreachableInCall(NodeRegion nr, DataFlowCall call) { none() }

  predicate allowParameterReturnInSelf(ParameterNode p) { none() }

  /** Only used to refine types, and v1 has a single type. */
  predicate localMustFlowStep(Node node1, Node node2) { none() }

  /** Access-to-subprogram values: one kind of call through them. */
  class LambdaCallKind = Unit;

  /**
   * `P'Access` (also `'Unchecked_Access`, `'Unrestricted_Access`) creates an access
   * value designating `P`'s body; a call through it runs that body.
   */
  predicate lambdaCreation(Node creation, LambdaCallKind kind, DataFlowCallable c) {
    exists(Raw::AttributeRef a, Raw::BasicDecl d |
      creation.asExpr() = a and
      a.getAttribute().getValue().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access"] and
      d =
        resolveSubpRenaming(CallResolution::instanceGeneric(a.getPrefix()
                .(Raw::Name)
                .getReferencedDecl())) and
      (c = bodyOf(d) or c = bodyOf(resolveSubpRenaming(d.(BasicDecl).getCompletion()))) and
      exists(kind)
    )
  }

  /** `Fn (X)` or `Fn.all (X)` calls through the access value `Fn`. */
  predicate lambdaCall(DataFlowCall call, LambdaCallKind kind, Node receiver) {
    isAccessCall(call, receiver.asExpr()) and exists(kind)
  }

  /**
   * An access-to-subprogram value stored in a record component reaches every read of
   * that component (`Cb.Op := P'Access; ... Cb.Op (X)`): the shared library tracks
   * where such values go without content, so this step stands in for the store and
   * the read. It does not tell objects of the record type apart.
   */
  predicate additionalLambdaFlowStep(Node nodeFrom, Node nodeTo, boolean preservesValue) {
    exists(Content c |
      exists(c.asComponent()) and
      storeStep(nodeFrom, c, _) and
      readStep(_, c, nodeTo)
    ) and
    preservesValue = true
  }

  predicate knownSourceModel(Node source, string model) { none() }

  predicate knownSinkModel(Node sink, string model) { none() }

  class DataFlowSecondLevelScope = Void;
}

/**
 * Holds if `n` is the write-back of the variable `call` passes for its `idx`th formal,
 * an `out` or `in out` one: the value the variable holds after the call.
 */
predicate outArgumentNode(LF::Node n, Raw::Expr call, int idx) {
  exists(SsaFlow::WriteDefSourceNode w |
    isOutActualDef(w.getDefinition(), call, idx) and
    n = LF::fromSsa(w)
  )
}

/** The Ada instantiation of the shared global data-flow library. */
module AdaDataFlow = DF::DataFlowMake<Raw::Location, AdaDataFlowInput>;
