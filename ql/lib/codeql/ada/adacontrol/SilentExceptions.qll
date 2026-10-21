/**
 * AdaControl rule `Silent_Exceptions`: exception handlers through which an exception can
 * disappear without being reported: no re-raise, return, requeue or call to a reporting
 * subprogram on every path (`docs/adacontrol.md`).
 *
 * As in AdaControl, the reporting must be "eye-visible": a report item written in the
 * handler, on every path through its statements. A report item only in a loop's body,
 * which may run no time, does not count.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms

module SilentExceptions {
  /** The constructs that count as reporting an exception. */
  signature predicate isReportSig(Raw::Stmt s);

  /**
   * Holds if `s` is a report item of AdaControl's kind `kind`: `explicit_raise` (`raise E`
   * or a call to `Ada.Exceptions.Raise_Exception`), `reraise` (`raise` or a call to
   * `Ada.Exceptions.Reraise_Occurrence`), `return`, `requeue`.
   */
  predicate isReportOfKind(Raw::Stmt s, string kind) {
    kind = "explicit_raise" and exists(s.(Raw::RaiseStmt).getExceptionName())
    or
    kind = "reraise" and s instanceof Raw::RaiseStmt and not exists(s.(Raw::RaiseStmt).getExceptionName())
    or
    kind = "explicit_raise" and
    s.(Raw::CallStmt).getCall().(Call).getTarget().hasQualifiedName("Ada.Exceptions.Raise_Exception")
    or
    kind = "reraise" and
    s.(Raw::CallStmt).getCall().(Call).getTarget().hasQualifiedName("Ada.Exceptions.Reraise_Occurrence")
    or
    kind = "return" and (s instanceof Raw::ReturnStmt or s instanceof Raw::ExtendedReturnStmt)
    or
    kind = "requeue" and s instanceof Raw::RequeueStmt
  }

  /** Holds if call statement `s` calls `entity` (a reporting procedure), through renamings. */
  predicate callsReporting(Raw::Stmt s, Raw::BasicDecl entity) {
    exists(Subprogram target | target = s.(Raw::CallStmt).getCall().(Call).getTarget() |
      target = entity or target.getADeclaration() = entity
    )
  }

  /** Gets the statement `s` is, seen through a statement name. */
  private Raw::Stmt unwrap(Raw::Stmt s) {
    result = s.(Raw::NamedStmt).getStmt()
    or
    not s instanceof Raw::NamedStmt and result = s
  }

  module Make<isReportSig/1 isReport> {
    /** Holds if every path through `stmts` passes a report item. */
    predicate alwaysReports(Raw::StmtList stmts) {
      exists(Raw::Stmt s | s = unwrap(stmts.getChild(_)) | reportsOnAllPaths(s))
    }

    /** Holds if every path through statement `s` passes a report item. */
    private predicate reportsOnAllPaths(Raw::Stmt s) {
      isReport(s)
      or
      exists(Raw::IfStmt i | i = s |
        alwaysReports(i.getThenStmts()) and
        alwaysReports(i.getElsePart().getStmts()) and
        forall(Raw::ElsifStmtPart e | e = i.getAlternatives().getChild(_) | alwaysReports(e.getStmts()))
      )
      or
      exists(Raw::CaseStmt c | c = s |
        forex(Raw::CaseStmtAlternative a | a = c.getAlternatives().getChild(_) | alwaysReports(a.getStmts()))
      )
      or
      alwaysReports([s.(Raw::BeginBlock).getStmts(), s.(Raw::DeclBlock).getStmts()].getStmts())
    }

    /** Holds if handler `h` is silent: some path through its statements reports nothing. */
    predicate isSilent(Raw::ExceptionHandler h) { not alwaysReports(h.getStmts()) }
  }

  /** Holds if handler `h` has a `when others` choice. */
  predicate handlesOthers(Raw::ExceptionHandler h) {
    h.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator
  }

  /** Holds if handler `h` handles exception `e` by name (or a renaming of it). */
  predicate handles(Raw::ExceptionHandler h, Raw::BasicDecl e) {
    exists(Raw::BasicDecl d | d = h.getHandledExceptions().getChild(_).(Raw::Name).getReferencedDecl() |
      d = e or d.getUltimateDecl() = e
    )
  }
}
