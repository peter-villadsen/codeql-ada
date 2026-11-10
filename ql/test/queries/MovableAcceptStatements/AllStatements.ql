/**
 * The analysis of `codeql.ada.adacontrol.MovableAcceptStatements` for the shipped
 * query's test sources: each statement that is not movable and why, and the
 * `certain` and `possible` statements.
 */

import ada
import codeql.ada.adacontrol.MovableAcceptStatements

from AdaNode s, string what
where
  s.fromSource() and
  (
    exists(string reason | MovableAcceptStatements::nonMovable(s, _, reason) |
      what = "not movable: " + reason
    )
    or
    MovableAcceptStatements::certain(s, _) and what = "certain"
    or
    MovableAcceptStatements::possible(s, _) and what = "possible"
  )
select s, what
