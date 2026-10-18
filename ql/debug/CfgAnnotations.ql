/**
 * @name Print CFG expectation annotations
 * @description For each line of each file, prints the complete inline
 *              expectation comment that the CFG conformance test expects on
 *              that line, ready to paste into the `.adb`.
 * @kind table
 * @id ada/debug/cfg-annotations
 *
 * Transcribe the output only *after* checking the graph against the rule in
 * `docs/cfg-design.md`. This query reports what the implementation does, which
 * is the thing under test — pasting it blindly turns a conformance test into a
 * tautology.
 */

import codeql.ada.test.CfgAnnotations

from string file, int line, string annotation
where
  annotation =
    "-- $ " +
      strictconcat(ControlFlowNode pred, SuccessorType t, ControlFlowNode succ, string value |
        pred.getASuccessor(t) = succ and
        file = annotationFile(pred) and
        line = annotationLine(pred) and
        value = edgeKey(pred, t, succ)
      |
        "edge=" + value, " " order by value
      )
select file, line, annotation order by file, line
