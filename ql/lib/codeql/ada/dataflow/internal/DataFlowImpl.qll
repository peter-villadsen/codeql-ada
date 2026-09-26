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
private Impl::Scopes::CfgScope bodyOf(Raw::BasicDecl d) { result = [d.(BasicDecl).getBody(), d] }

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
   * (`TOutReturnKind`, one per formal position, D-022). Extended return statements
   * (`return R : T do ... end return`) are not modelled (docs/dataflow-design.md).
   */
  class ReturnNode extends Node {
    private ReturnKind kind;

    ReturnNode() {
      kind = TNormalReturnKind() and
      (
        this.asExpr() = any(Raw::ReturnStmt r).getReturnExpr()
        or
        this.asExpr() = any(Raw::ExprFunction f).getExpr()
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

  /** No post-update nodes: without content flow v1 has no stores for them to receive. */
  class PostUpdateNode extends Node {
    PostUpdateNode() { none() }

    Node getPreUpdateNode() { none() }
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
  }

  DataFlowType getNodeType(Node node) { exists(node) and result = TUnitType() }

  /**
   * Hides the SSA layer's bookkeeping nodes (definitions, phis, write sources, exit
   * reads) from path explanations, except an `out`/`in out` write-back: that is the
   * hop where a value re-enters the caller, and a path should show it.
   */
  predicate nodeIsHidden(Node node) { exists(node.asSsaNode()) and not node instanceof OutNode }

  class DataFlowExpr = Raw::Expr;

  Node exprNode(DataFlowExpr e) { result.asExpr() = e }

  /** A call with a resolvable target declaration (`getCallTarget`), written with or without parentheses. */
  class DataFlowCall extends Raw::Expr {
    DataFlowCall() { exists(getCallTarget(this)) }

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
      result = bodyOf(d) or result = bodyOf(resolveSubpRenaming(d.(BasicDecl).getBody()))
    )
  }

  OutNode getAnOutNode(DataFlowCall call, ReturnKind kind) { outNode(result, call, kind) }

  /** A single type (D-023): no type-based pruning in v1. */
  class DataFlowType extends TDataFlowType {
    string toString() { result = "" }
  }

  predicate compatibleTypes(DataFlowType t1, DataFlowType t2) { any() }

  predicate typeStrongerThan(DataFlowType t1, DataFlowType t2) { none() }

  /** No content (D-023): record components and array elements are not tracked in v1. */
  class Content = Void;

  predicate forceHighPrecision(Content c) { none() }

  class ContentSet extends Void {
    Content getAStoreContent() { none() }

    Content getAReadContent() { none() }
  }

  class ContentApprox = Void;

  ContentApprox getContentApprox(Content c) { none() }

  /** A 0-based formal position, flattened across `ParamSpec` groups. */
  class ParameterPosition = Position;

  /** The formal position an actual binds to, by position or by name. */
  class ArgumentPosition = Position;

  predicate parameterMatch(ParameterPosition ppos, ArgumentPosition apos) { ppos = apos }

  predicate simpleLocalFlowStep(Node node1, Node node2, string model) {
    LF::localFlowStep(node1, node2) and model = ""
  }

  /** No jump steps: library-level (package) variables are not tracked in v1. */
  predicate jumpStep(Node node1, Node node2) { none() }

  predicate readStep(Node node1, ContentSet c, Node node2) { none() }

  predicate storeStep(Node node1, ContentSet c, Node node2) { none() }

  predicate clearsContent(Node n, ContentSet c) { none() }

  predicate expectsContent(Node n, ContentSet c) { none() }

  class NodeRegion extends Void {
    predicate contains(Node n) { none() }
  }

  predicate isUnreachableInCall(NodeRegion nr, DataFlowCall call) { none() }

  predicate allowParameterReturnInSelf(ParameterNode p) { none() }

  /** Only used to refine types, and v1 has a single type. */
  predicate localMustFlowStep(Node node1, Node node2) { none() }

  /** No access-to-subprogram flow (D-023). */
  class LambdaCallKind = Unit;

  predicate lambdaCreation(Node creation, LambdaCallKind kind, DataFlowCallable c) { none() }

  predicate lambdaCall(DataFlowCall call, LambdaCallKind kind, Node receiver) { none() }

  predicate additionalLambdaFlowStep(Node nodeFrom, Node nodeTo, boolean preservesValue) { none() }

  predicate knownSourceModel(Node source, string model) { none() }

  predicate knownSinkModel(Node sink, string model) { none() }

  class DataFlowSecondLevelScope = Void;
}

/** The Ada instantiation of the shared global data-flow library. */
module AdaDataFlow = DF::DataFlowMake<Raw::Location, AdaDataFlowInput>;
