/**
 * @name Call consistency
 * @description Compares the library's `Call` (evaluated by a syntactic rule) with the
 *              data-flow library's calls (evaluated where the CFG has a node). Lists
 *              each call only one of them has, with its parent's class. Expected:
 *              "Call only" rows in elaboration contexts the CFG does not model (type
 *              and range declarations); no "data flow only" rows.
 * @id ada/debug/call-consistency
 * @kind table
 */

import ada
private import codeql.ada.dataflow.internal.SsaImpl as SsaImpl

from Expr e, string which
where
  e.fromSource() and
  (
    e instanceof Call and not exists(SsaImpl::getCallTarget(e)) and which = "Call only"
    or
    exists(SsaImpl::getCallTarget(e)) and not e instanceof Call and which = "data flow only"
  )
select e, which, e.getParent().getAPrimaryQlClass(), e.getLocation().toString()
