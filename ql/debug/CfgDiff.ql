/**
 * @name Differences between the two control-flow graphs
 * @description Compares the graph built on `codeql.controlflow.Cfg`
 *              (`ControlFlowGraphImpl.qll`) with the one built on
 *              `codeql.controlflow.ControlFlowGraph` (`ControlFlowGraphImpl2.qll`):
 *              which AST nodes each reaches, and which comparable node follows which
 *              (CFG migration, Step 2; see `docs/cfg-migration-plan.md` §6).
 * @kind table
 * @id ada/debug/cfg-diff
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Old
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl2 as New

/**
 * Holds if `a` is represented at the same point by both graphs, so that the
 * successor relations can be compared on it: a leaf, a post-order expression, or a
 * statement whose node follows its parts in both. Not an `if`, `case`, loop or
 * `select` (a join node at the end in the old graph, a node at the start in the new)
 * nor a short-circuit operator or `if` expression (likewise).
 */
predicate comparable(Raw::AdaNode a) {
  exists(Old::CfgImpl::AstCfgNode n | n.getAstNode() = a) and
  not a instanceof Raw::IfStmt and
  not a instanceof Raw::CaseStmt and
  not a instanceof Raw::BaseLoopStmt and
  not a instanceof Raw::SelectStmt and
  not a instanceof Raw::IfExpr and
  not a instanceof Raw::CaseExpr and
  not a.(Raw::BinOp).getOp() instanceof Raw::OpAndThen and
  not a.(Raw::BinOp).getOp() instanceof Raw::OpOrElse and
  not a instanceof Raw::ExtendedReturnStmt
}

/** Gets `a` as `kind@line:col`. */
string key(Raw::AdaNode a) {
  exists(int l, int c |
    a.getLocation().hasLocationInfo(_, l, c, _, _) and
    result = a.getAPrimaryQlClass() + "@" + l + ":" + c
  )
}

/** Gets the file `a` is in. */
string file(Raw::AdaNode a) {
  exists(string p | a.getLocation().hasLocationInfo(p, _, _, _, _) | result = p.regexpReplaceAll(".*/", ""))
}

// --- the old graph ---------------------------------------------------------
private predicate oldRep(Old::CfgImpl::Node n, string k) {
  exists(Raw::AdaNode a | comparable(a) and n.(Old::CfgImpl::AstCfgNode).getAstNode() = a and k = key(a))
  or
  n instanceof Old::CfgImpl::AnnotatedExitNode and
  exists(string s |
    (if n.(Old::CfgImpl::AnnotatedExitNode).isNormal() then s = "normal" else s = "abnormal") and
    k = "exit(" + s + ")@" + key(n.getScope())
  )
}

private predicate oldNext(Old::CfgImpl::Node n, string k) {
  exists(Old::CfgImpl::Node m | m = n.getASuccessor() |
    oldRep(m, k)
    or
    not oldRep(m, _) and oldNext(m, k)
  )
}

predicate oldEdge(string f, string k1, string k2) {
  exists(Old::CfgImpl::Node n, Raw::AdaNode a |
    n.(Old::CfgImpl::AstCfgNode).getAstNode() = a and
    comparable(a) and
    k1 = key(a) and
    f = file(a) and
    oldNext(n, k2)
  )
}

predicate oldReached(Raw::AdaNode a) { exists(Old::CfgImpl::AstCfgNode n | n.getAstNode() = a) }

// --- the new graph ---------------------------------------------------------
private predicate newReachable(New::ControlFlowNode n) {
  n instanceof New::ControlFlow::EntryNode
  or
  exists(New::ControlFlowNode p | newReachable(p) and n = p.getASuccessor())
}

private predicate newRep(New::ControlFlowNode n, string k) {
  exists(Raw::AdaNode a | comparable(a) and n.injects(a) and k = key(a))
  or
  exists(string s |
    n instanceof New::ControlFlow::NormalExitNode and s = "normal"
    or
    n instanceof New::ControlFlow::ExceptionalExitNode and s = "abnormal"
  |
    k = "exit(" + s + ")@" + key(n.getEnclosingCallable())
  )
}

private predicate newNext(New::ControlFlowNode n, string k) {
  exists(New::ControlFlowNode m | m = n.getASuccessor() |
    newRep(m, k)
    or
    not newRep(m, _) and newNext(m, k)
  )
}

predicate newEdge(string f, string k1, string k2) {
  exists(New::ControlFlowNode n, Raw::AdaNode a |
    newReachable(n) and
    n.injects(a) and
    comparable(a) and
    k1 = key(a) and
    f = file(a) and
    newNext(n, k2)
  )
}

predicate newReached(Raw::AdaNode a) {
  exists(New::ControlFlowNode n | newReachable(n) and n.injects(a))
}

// --- the differences -------------------------------------------------------
/** An AST node the old graph reaches and the new one does not. */
query predicate onlyOldReached(string f, string k) {
  exists(Raw::AdaNode a | oldReached(a) and not newReached(a) and k = key(a) and f = file(a))
}

/** A comparable AST node the new graph reaches and the old one does not. */
query predicate onlyNewReached(string f, string k) {
  exists(Raw::AdaNode a |
    newReached(a) and
    not oldReached(a) and
    (a instanceof Raw::Expr or a instanceof Raw::SimpleStmt) and
    k = key(a) and
    f = file(a)
  )
}

query predicate onlyOldEdge(string f, string k1, string k2) {
  oldEdge(f, k1, k2) and not newEdge(f, k1, k2)
}

query predicate onlyNewEdge(string f, string k1, string k2) {
  newEdge(f, k1, k2) and not oldEdge(f, k1, k2)
}

/** How many comparable edges each graph has: a check that the comparison is not vacuous. */
query predicate edgeCounts(int oldEdges, int newEdges) {
  oldEdges = count(string f, string a, string b | oldEdge(f, a, b)) and
  newEdges = count(string f, string a, string b | newEdge(f, a, b))
}
