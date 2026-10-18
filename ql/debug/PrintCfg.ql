/**
 * @name Print the control-flow graph
 * @description Dumps every edge of the Ada control-flow graph as
 *              `predecessor -> [label] -> successor`, in the same node
 *              rendering the conformance-test annotations use.
 * @kind table
 * @id ada/debug/print-cfg
 */

import codeql.ada.test.CfgAnnotations

from ControlFlowNode pred, SuccessorType t, ControlFlowNode succ
where pred.getASuccessor(t) = succ
select annotationFile(pred) as file, nodeKey(pred) as predecessor, t.toString() as label,
  nodeKey(succ) as successor, annotationLine(pred) as annotate_on_line
  order by file, annotate_on_line, predecessor, label, successor
