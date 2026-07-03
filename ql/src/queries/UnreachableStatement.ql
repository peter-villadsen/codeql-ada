/**
 * @name Unreachable statement
 * @description A statement immediately following an unconditional `raise` or `return`
 *              in the same statement sequence can never execute -- control has already
 *              left the sequence by the time it would be reached. (Only the immediate
 *              next statement is flagged, and a following label is never flagged, since
 *              a `goto` elsewhere in the unit could still jump to code after it -- this
 *              query does not analyze `goto` targets.)
 * @id ada/unreachable-statement
 * @kind problem
 * @problem.severity warning
 * @tags maintainability correctness
 */

import ada

from Raw::StmtList list, Raw::AdaNode terminator, int i, Raw::AdaNode nextStmt, string how
where
  terminator = list.getChild(i) and
  nextStmt = list.getChild(i + 1) and
  not nextStmt instanceof Raw::Label and
  (
    terminator instanceof Raw::RaiseStmt and how = "raises an exception"
    or
    terminator instanceof Raw::ReturnStmt and how = "returns"
  )
select nextStmt, "This statement is unreachable: the previous statement always " + how + "."
