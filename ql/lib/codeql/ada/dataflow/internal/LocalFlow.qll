/**
 * Local (intraprocedural) data flow for Ada: Task 9.3, see `docs/dataflow-design.md`.
 *
 * The SSA part of the graph -- definitions, phis, reads and the steps between them --
 * comes from `codeql/ssa`'s `DataFlowIntegration` (`SsaFlow`, in `SsaImpl.qll`); it is
 * not rebuilt here. What that module leaves to the language, and this file adds:
 *
 * - `Node` also covers every expression with a CFG node, not only reads of tracked
 *   variables, so a value can be followed from where it is computed.
 * - A step from the value a write stores (an assignment's right-hand side, an
 *   initialiser) into that write's definition.
 * - Value-preserving steps through expressions: parentheses, qualified expressions,
 *   and the branches of `if` and `case` expressions.
 *
 * - A node for each formal parameter that receives a value from the caller, with a
 *   step into the formal's entry definition.
 *
 * Cross-procedure flow (Task 9.4, `DataFlowImpl.qll`) builds `codeql/dataflow`'s
 * `InputSig` on top of this `Node` and uses `localFlowStep` as its
 * `simpleLocalFlowStep`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl
private import codeql.ada.dataflow.internal.SsaImpl
private import codeql.ada.dataflow.internal.Content
private import ada

/** Holds if `e` has a node in the control-flow graph, i.e. is evaluated. */
private predicate hasCfgNode(Raw::Expr e) {
  exists(Impl::ControlFlowNode n | n.injects(e))
}

private newtype TNode =
  TExprNode(Raw::Expr e) { hasCfgNode(e) } or
  TSsaNode(SsaFlow::Node n) { not exists(n.(SsaFlow::ExprNode).getExpr().asExpr()) } or
  TParameterNode(SsaSourceVariable p) { formalOf(p, _, _, _) and formalReceivesArgument(p) } or
  TPostUpdateNode(Raw::Expr e) {
    hasCfgNode(e) and isUpdatedPrefix(e) and not exists(ssaPostUpdate(e))
  }

/** Gets the post-update node the SSA layer has for variable read `e`. */
private SsaFlow::ExprPostUpdateNode ssaPostUpdate(Raw::Expr e) { result.getExpr().asExpr() = e }

/**
 * A node in the local data-flow graph: an expression (`asExpr()`), a formal parameter
 * receiving the caller's value (`asParameter()`), or a node the SSA layer adds -- a
 * definition, a phi, the source of a write, a post-update node, or the exit read of an
 * `out`/`in out` formal.
 */
class Node extends TNode {
  /** Gets the expression this node is, if any. */
  Raw::Expr asExpr() { this = TExprNode(result) }

  /** Gets the formal parameter this node is, if any. */
  SsaSourceVariable asParameter() { this = TParameterNode(result) }

  /** Gets the SSA data-flow node this node is, if it is neither of the above. */
  SsaFlow::Node asSsaNode() { this = TSsaNode(result) }

  /**
   * Gets the expression this node is the post-update node of: the object a store
   * into one of its components or elements updates (`R` in `R.A := X`).
   */
  Raw::Expr asPostUpdateOf() {
    this = TPostUpdateNode(result)
    or
    this = TSsaNode(ssaPostUpdate(result))
  }

  /**
   * Gets the actual whose value after the call this node is: the write-back of an
   * `out` or `in out` actual, shown as that actual rather than as an SSA definition.
   */
  private Raw::Expr getWrittenBackActual() {
    exists(Raw::Expr call, int idx |
      isOutActualDef(this.asSsaNode().(SsaFlow::WriteDefSourceNode).getDefinition(), call, idx) and
      callActual(call, result, idx)
    )
  }

  /** Gets a textual representation of this node. */
  string toString() {
    result = this.asExpr().toString()
    or
    result = "[param] " + this.asParameter().toString()
    or
    result = this.getWrittenBackActual().toString() + " [post update]"
    or
    not exists(this.getWrittenBackActual()) and result = this.asSsaNode().toString()
    or
    this = TPostUpdateNode(_) and result = this.asPostUpdateOf().toString() + " [post update]"
  }

  /** Gets the location of this node. */
  Raw::Location getLocation() {
    result = this.asExpr().getLocation()
    or
    result = this.asParameter().getLocation()
    or
    result = this.getWrittenBackActual().getLocation()
    or
    not exists(this.getWrittenBackActual()) and result = this.asSsaNode().getLocation()
    or
    this = TPostUpdateNode(_) and result = this.asPostUpdateOf().getLocation()
  }
}

/** Gets the post-update node of `e`, the object a component or element store updates. */
Node postUpdateOf(Raw::Expr e) { result.asPostUpdateOf() = e and isUpdatedPrefix(e) }

/** Gets the node for SSA data-flow node `n`: reads are represented by their expression. */
Node fromSsa(SsaFlow::Node n) {
  result = TExprNode(n.(SsaFlow::ExprNode).getExpr().asExpr())
  or
  result = TSsaNode(n)
}

/**
 * Holds if `n` is the exit read of an `out`/`in out` formal other than `v`.
 *
 * The exit reads of all of a scope's `out`/`in out` formals sit at the one normal
 * exit node, and `DataFlowIntegration` matches a read to a variable by CFG position
 * alone (`ReadNode.readsAt`), so its steps into one formal's exit read also arrive
 * from every other formal read there. Each step carries its variable, which is what
 * tells them apart: without this filter, `Swap (A, B)` would return `B`'s value
 * through `A`.
 */
private predicate isExitReadOfOther(SsaFlow::Node n, SsaSourceVariable v) {
  exists(SsaSourceVariable w | w = n.(SsaFlow::ExprNode).getExpr().asParamExitRead() | w != v)
}

/** Holds if `e2`'s value is `e1`'s value. */
private predicate exprStep(Raw::Expr e1, Raw::Expr e2) {
  e1 = e2.(Raw::ParenExpr).getExpr()
  or
  e1 = e2.(Raw::QualExpr).getSuffix()
  or
  e1 = [e2.(Raw::IfExpr).getThenExpr(), e2.(Raw::IfExpr).getElseExpr()]
  or
  e1 = e2.(Raw::IfExpr).getAlternatives().getChild(_).(Raw::ElsifExprPart).getThenExpr()
  or
  e1 = e2.(Raw::CaseExpr).getCases().getChild(_).(Raw::CaseExprAlternative).getExpr()
}

/** Holds if there is a local, value-preserving flow step from `nodeFrom` to `nodeTo`. */
predicate localFlowStep(Node nodeFrom, Node nodeTo) {
  exists(SsaFlow::Node n1, SsaFlow::Node n2, SsaSourceVariable v |
    SsaFlow::localFlowStep(v, n1, n2, _) and
    not isExitReadOfOther(n1, v) and
    not isExitReadOfOther(n2, v) and
    nodeFrom = fromSsa(n1) and
    nodeTo = fromSsa(n2)
  )
  or
  exists(SsaFlow::WriteDefSourceNode w |
    nodeFrom.asExpr() = getWrittenValue(w.getDefinition()) and
    nodeTo = fromSsa(w)
  )
  or
  exprStep(nodeFrom.asExpr(), nodeTo.asExpr())
  or
  exists(SsaFlow::WriteDefSourceNode w |
    isParameterEntryDef(w.getDefinition(), nodeFrom.asParameter()) and
    nodeTo = fromSsa(w)
  )
  or
  // a formal's default value, evaluated at the callee's entry, may be its value
  // (an over-approximation: also on calls that pass an actual; Task 9.6)
  exists(SsaFlow::WriteDefSourceNode w, Raw::ParamSpec ps |
    nodeFrom.asExpr() = ps.getDefaultExpr() and
    isParameterEntryDef(w.getDefinition(), ps.(BasicDecl).getADefiningName()) and
    nodeTo = fromSsa(w)
  )
}

/** Holds if the value of `source` may reach `sink` through zero or more local steps. */
predicate localFlow(Node source, Node sink) { localFlowStep*(source, sink) }

/**
 * Holds if guard `g` evaluating to `branch` validates expression `e` -- e.g. `g` is
 * `Is_Safe (e)` and `branch` is `true`.
 */
signature predicate guardChecksSig(Raw::Expr g, Raw::Expr e, boolean branch);

/**
 * Provides barrier nodes for a validating guard: uses of the same SSA value as a
 * checked expression, in blocks the guard controls with the validating outcome.
 */
module BarrierGuard<guardChecksSig/3 guardChecks> {
  /**
   * The check, as the shared SSA library wants it. The Guards library
   * (`codeql.ada.controlflow.Guards`) carries it through `and then`, `or else`, `not`,
   * parentheses and SSA variables: in `if C and then Is_Safe (X)` the block that runs
   * when the whole is true is controlled by `Is_Safe (X)` being true.
   */
  private predicate guardChecksAdapted(
    SsaDataFlowInput::Guard g, SsaDataFlowInput::Expr e, SsaDataFlowInput::GuardValue v
  ) {
    guardChecks(g.(Raw::Expr), e.asExpr(), v.asBooleanValue())
  }

  /** Gets a node that is safely guarded by a `guardChecks` guard. */
  Node getABarrierNode() {
    result = fromSsa(SsaFlow::BarrierGuard<guardChecksAdapted/3>::getABarrierNode())
  }
}
