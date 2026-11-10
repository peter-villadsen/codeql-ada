/**
 * @name Statement could follow the rendezvous
 * @description The caller of an entry waits until the `accept` body completes. A statement
 *              at the end of the body that neither uses the entry's parameters nor
 *              synchronizes could come after `end`, shortening the wait. AdaControl rule
 *              `Movable_Accept_Statements`, `certain`: the statements after the last
 *              one that references a parameter, synchronizes (`delay`, `accept`,
 *              `select`, `requeue`, `abort`, entry calls) or leaves the body. `possible`,
 *              with a simple data flow, is in
 *              `codeql.ada.adacontrol.MovableAcceptStatements` (`docs/adacontrol.md`).
 * @id ada/movable-accept-statements
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags efficiency concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.MovableAcceptStatements

from AdaNode s, Raw::AcceptStmtWithStmts a
where
  a.fromSource() and
  MovableAcceptStatements::certain(s, a) and
  // one result per accept: the first statement that could move
  not exists(AdaNode t, int i, int j |
    MovableAcceptStatements::certain(t, a) and
    t = MovableAcceptStatements::bodyStmt(a, i) and
    s = MovableAcceptStatements::bodyStmt(a, j) and
    i < j
  )
select s, "This statement and the ones after it in the $@ could follow the rendezvous.", a,
  "accept body"
