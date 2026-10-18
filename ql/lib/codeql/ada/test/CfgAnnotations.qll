/**
 * The canonical rendering of CFG nodes and edges used by the inline-expectation
 * annotations in the CFG conformance tests.
 *
 * This lives in the library pack, rather than beside the tests, so that the
 * conformance check (`ql/test/library/Cfg/CfgConformance.qll`) and the debug
 * queries that print annotations for transcription (`ql/debug/`) share one
 * definition and cannot drift apart.
 *
 * See `docs/cfg-design.md` for the annotation format and the workflow.
 */

import codeql.ada.controlflow.ControlFlowGraph

/**
 * Gets the annotation key for `n`: its kind followed by its position, as
 * `<kind>@<line>:<column>`.
 *
 * An AST node is named by its primary QL class rather than its `toString` (which
 * shows source text, D-027), and spaces are squeezed out, because an annotation value
 * may not contain whitespace. The node that represents an AST node renders as
 * `AssignStmt@25:7`; its other nodes carry the library's tag, as
 * `before:AssignStmt@25:7`, `after:IfStmt@12:4`, `after-true:Identifier@12:7` or
 * `add.[LoopHeader]:LoopStmt@9:4`. A scope's entry renders as `enterSubpBody@1:1` and
 * its exits as `exitSubpBody(normal)@1:1`, `exitSubpBody(abnormal)@1:1` and
 * `exitSubpBody@1:1`.
 */
string nodeKey(ControlFlowNode n) {
  exists(int l, int c |
    n.getLocation().hasLocationInfo(_, l, c, _, _) and
    result = nodeKind(n).replaceAll(" ", "") + "@" + l + ":" + c
  )
}

/** Gets the kind of `n`: see `nodeKey`. */
private string nodeKind(ControlFlowNode n) {
  exists(string scope | scope = n.getEnclosingCallable().getAPrimaryQlClass() |
    n instanceof ControlFlow::EntryNode and result = "enter " + scope
    or
    n instanceof ControlFlow::NormalExitNode and result = "exit " + scope + " (normal)"
    or
    n instanceof ControlFlow::ExceptionalExitNode and result = "exit " + scope + " (abnormal)"
    or
    n instanceof ControlFlow::ExitNode and result = "exit " + scope
  )
  or
  not n instanceof ControlFlow::EntryNode and
  not n instanceof ControlFlow::AnnotatedExitNode and
  not n instanceof ControlFlow::ExitNode and
  exists(string cls | cls = n.getAstNode().getAPrimaryQlClass() |
    n.injects(_) and result = cls
    or
    // `getIdTag` is the library's own name for the kind of node (`before`, `after`, ...)
    not n.injects(_) and result = n.getIdTag() + ":" + cls
  )
}

/**
 * Gets the annotation value for the edge `pred -[t]-> succ`, that is, the text
 * following `edge=` in an expectation comment.
 */
string edgeKey(ControlFlowNode pred, SuccessorType t, ControlFlowNode succ) {
  result = nodeKey(pred) + "|" + t.toString() + "|" + nodeKey(succ)
}

/**
 * Gets the 1-based line on which an expectation for the edge out of `n` must be
 * written: the line where `n` *ends*, since the framework matches a comment's
 * start line against the result location's end line.
 */
int annotationLine(ControlFlowNode n) { n.getLocation().hasLocationInfo(_, _, _, result, _) }

/** Gets the base name of the file containing `n`. */
string annotationFile(ControlFlowNode n) {
  exists(string p |
    n.getLocation().hasLocationInfo(p, _, _, _, _) and
    result = p.regexpReplaceAll(".*[/\\\\]", "")
  )
}
