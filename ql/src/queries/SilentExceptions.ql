/**
 * @name Exception silently handled by when others
 * @description A `when others` handler with a path that neither re-raises, returns,
 *              requeues nor calls anything (to report the exception) makes every
 *              exception disappear on that path. AdaControl rule `Silent_Exceptions` with
 *              `with others, raise, return, requeue`, and any procedure call standing for
 *              the reporting procedures a team would list. Handlers containing only
 *              `null` are `ada/exception-swallowing`'s. Other exceptions and reporting
 *              entities are in `codeql.ada.adacontrol.SilentExceptions` for a query of
 *              your own (`docs/adacontrol.md`).
 * @id ada/silent-exceptions
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.SilentExceptions

predicate isReport(Stmt s) {
  SilentExceptions::isReportOfKind(s, _) or
  s instanceof CallStmt
}

module Silent = SilentExceptions::Make<isReport/1>;

from ExceptionHandler h
where
  SilentExceptions::handlesOthers(h) and
  Silent::isSilent(h) and
  // only `null`: ada/exception-swallowing
  not forex(AdaNode s | s = h.getStmts().getChild(_) | s instanceof NullStmt) and
  h.fromSource()
select h, "This handler can let any exception disappear without reporting it."
