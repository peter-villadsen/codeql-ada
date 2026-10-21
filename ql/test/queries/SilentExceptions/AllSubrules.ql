/**
 * `codeql.ada.adacontrol.SilentExceptions` on the shipped query's test sources, with only
 * `raise` and `return` as report items (no reporting procedure), and with `Log`
 * (a renaming of `Ada.Text_IO.Put_Line`) as one; and the exceptions each handler handles.
 */

import ada
import codeql.ada.adacontrol.SilentExceptions

predicate raiseOrReturn(Stmt s) { SilentExceptions::isReportOfKind(s, ["explicit_raise", "reraise", "return"]) }

predicate withLog(Stmt s) {
  raiseOrReturn(s)
  or
  exists(BasicDecl log | log.hasQualifiedName("Ada.Text_IO.Put_Line") | SilentExceptions::callsReporting(s, log))
}

module Strict = SilentExceptions::Make<raiseOrReturn/1>;

module Logged = SilentExceptions::Make<withLog/1>;

from ExceptionHandler h, string what
where
  h.fromSource() and
  (
    Strict::isSilent(h) and what = "silent (raise, return)"
    or
    Logged::isSilent(h) and what = "silent (raise, return, Put_Line)"
    or
    SilentExceptions::handlesOthers(h) and what = "others"
    or
    exists(BasicDecl e | SilentExceptions::handles(h, e) | what = "handles " + e.getQualifiedName())
  )
select h, what
