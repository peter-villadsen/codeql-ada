/**
 * @name Print the control-flow graph (shared ControlFlowGraph library)
 * @description Dumps every edge of the Ada control-flow graph built on
 *              `codeql.controlflow.ControlFlowGraph` (CFG migration, Step 2).
 * @kind table
 * @id ada/debug/print-cfg2
 */

private import codeql.ada.controlflow.internal.ControlFlowGraphImpl2
private import codeql.controlflow.SuccessorType

from ControlFlowNode pred, SuccessorType t, ControlFlowNode succ, string path, int line, int col
where
  pred.getASuccessor(t) = succ and
  pred.getLocation().hasLocationInfo(path, line, col, _, _)
select path.regexpReplaceAll(".*/", "") as file, line, col, pred.toString() as predecessor,
  t.toString() as label, succ.toString() as successor,
  succ.getLocation().getStartLine() as succLine
  order by file, line, col, predecessor, label, successor
