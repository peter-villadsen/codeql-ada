/**
 * The CFG conformance test: checks that the control-flow graph built for each
 * `test.adb` in this directory tree matches, edge for edge, the expectations
 * annotated in that file.
 *
 * A test query is a one-liner:
 *
 * ```ql
 * import library.Cfg.CfgConformance
 * ```
 *
 * paired with an **empty** `test.expected`. Every edge must be annotated and
 * every annotation must correspond to an edge, so the check is exhaustive in
 * both directions: an unannotated edge fails with "Unexpected result", an
 * annotation with no matching edge fails with "Missing result".
 *
 * ## Annotation format
 *
 * ```
 * -- $ edge=<predecessor>|<label>|<successor>
 * ```
 *
 * where each node is rendered by `nodeKey` as `<kind>@<line>:<column>`:
 *
 * | Node | Rendering |
 * |---|---|
 * | AST node | its primary QL class, e.g. `AssignStmt@25:7` |
 * | scope entry | `enterSubpBody@1:1` |
 * | scope exit | `exitSubpBody@1:1` |
 * | annotated scope exit | `exitSubpBody(normal)@1:1`, `exitSubpBody(abnormal)@1:1` |
 *
 * and `<label>` is the `SuccessorType`: `successor`, `true`, `false`, `return`,
 * `exception`, `break` or `goto`.
 *
 * The annotation goes on the line where the **predecessor** node ends — for an
 * `IfStmt` spanning lines 5-11, on line 11 (`end if;`). For the single-line
 * nodes that make up most of a graph the distinction does not arise.
 *
 * `ql/debug/CfgAnnotations.ql` prints the complete annotation comment for every
 * line of a file, so annotations are transcribed rather than typed. Transcribe
 * only after checking the graph against the rule in `docs/cfg-design.md`: the
 * debug query reports what the implementation *does*, which is the thing under
 * test.
 */

import codeql.ada.controlflow.Cfg
private import codeql.ada.test.CfgAnnotations
private import codeql.ada.test.InlineExpectationsTest

private module CfgEdgeTest implements TestSig {
  string getARelevantTag() { result = "edge" }

  predicate hasActualResult(Location location, string element, string tag, string value) {
    exists(CfgNode pred, SuccessorType t, CfgNode succ |
      pred.getASuccessor(t) = succ and
      location = pred.getLocation() and
      element = pred.toString() and
      tag = "edge" and
      value = edgeKey(pred, t, succ)
    )
  }
}

import MakeTest<CfgEdgeTest>
