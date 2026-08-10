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

import codeql.ada.controlflow.Cfg

/**
 * Gets the annotation key for `n`: its kind followed by its position, as
 * `<kind>@<line>:<column>`.
 *
 * The kind is the framework's rendering with spaces squeezed out, because an
 * annotation value may not contain whitespace: an AST node renders as its
 * primary QL class (`AssignStmt@25:7`), a scope entry as `enterSubpBody@1:1`,
 * and an annotated scope exit as `exitSubpBody(normal)@1:1`.
 */
string nodeKey(CfgNode n) {
  exists(int l, int c |
    n.getLocation().hasLocationInfo(_, l, c, _, _) and
    result = n.toString().replaceAll(" ", "") + "@" + l + ":" + c
  )
}

/**
 * Gets the annotation value for the edge `pred -[t]-> succ`, that is, the text
 * following `edge=` in an expectation comment.
 */
string edgeKey(CfgNode pred, SuccessorType t, CfgNode succ) {
  result = nodeKey(pred) + "|" + t.toString() + "|" + nodeKey(succ)
}

/**
 * Gets the 1-based line on which an expectation for the edge out of `n` must be
 * written: the line where `n` *ends*, since the framework matches a comment's
 * start line against the result location's end line.
 */
int annotationLine(CfgNode n) { n.getLocation().hasLocationInfo(_, _, _, result, _) }

/** Gets the base name of the file containing `n`. */
string annotationFile(CfgNode n) {
  exists(string p |
    n.getLocation().hasLocationInfo(p, _, _, _, _) and
    result = p.regexpReplaceAll(".*[/\\\\]", "")
  )
}
