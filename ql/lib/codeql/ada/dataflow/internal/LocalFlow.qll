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
private import ada

/** Holds if `e` has a node in the control-flow graph, i.e. is evaluated. */
private predicate hasCfgNode(Raw::Expr e) {
  exists(Impl::CfgImpl::AstCfgNode n | n.getAstNode() = e)
}

private newtype TNode =
  TExprNode(Raw::Expr e) { hasCfgNode(e) } or
  TSsaNode(SsaFlow::Node n) { not exists(n.(SsaFlow::ExprNode).getExpr().asExpr()) } or
  TParameterNode(SsaSourceVariable p) { formalOf(p, _, _, _) and formalReceivesArgument(p) }

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

  /** Gets a textual representation of this node. */
  string toString() {
    result = this.asExpr().toString()
    or
    result = "[param] " + this.asParameter().toString()
    or
    result = this.asSsaNode().toString()
  }

  /** Gets the location of this node. */
  Raw::Location getLocation() {
    result = this.asExpr().getLocation()
    or
    result = this.asParameter().getLocation()
    or
    result = this.asSsaNode().getLocation()
  }
}

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
   * Lifts `guardChecks` through the logical operators, because only an expression
   * that ends a basic block with Boolean edges is a guard: in `if C and then
   * Is_Safe (X)` that is the whole `and then` (its right operand completes normally
   * into it, see `docs/cfg-design.md`), and the check is only implied by it. A
   * conjunction is true only if both operands are; a disjunction is false only if
   * both are; `not` inverts; parentheses are transparent.
   */
  private predicate guardChecksLifted(Raw::Expr g, Raw::Expr e, boolean branch) {
    guardChecks(g, e, branch)
    or
    exists(Raw::BinOp op | op = g |
      (op.getOp() instanceof Raw::OpAndThen or op.getOp() instanceof Raw::OpAnd) and
      branch = true and
      guardChecksLifted([op.getLeft(), op.getRight()], e, true)
      or
      (op.getOp() instanceof Raw::OpOrElse or op.getOp() instanceof Raw::OpOr) and
      branch = false and
      guardChecksLifted([op.getLeft(), op.getRight()], e, false)
    )
    or
    exists(Raw::UnOp op | op = g and op.getOp() instanceof Raw::OpNot |
      guardChecksLifted(op.getExpr(), e, branch.booleanNot())
    )
    or
    guardChecksLifted(g.(Raw::ParenExpr).getExpr(), e, branch)
  }

  private predicate guardChecksAdapted(
    SsaDataFlowInput::Guard g, SsaDataFlowInput::Expr e, SsaDataFlowInput::GuardValue branch
  ) {
    guardChecksLifted(g, e.asExpr(), branch)
  }

  /** Gets a node that is safely guarded by a `guardChecks` guard. */
  Node getABarrierNode() {
    result = fromSsa(SsaFlow::BarrierGuard<guardChecksAdapted/3>::getABarrierNode())
  }
}
