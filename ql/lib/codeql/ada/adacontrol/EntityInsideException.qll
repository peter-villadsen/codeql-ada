/**
 * AdaControl rule `Entity_Inside_Exception`: references to given entities, calls, or
 * entry calls inside exception handlers (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls

module EntityInsideException {
  /** Holds if `n` is in the statements of exception handler `h`. */
  predicate inHandler(Raw::AdaNode n, Raw::ExceptionHandler h) { n.getParent+() = h.getStmts() }

  /** Holds if name `n`, in handler `h`, refers to `entity` (or a renaming of it). */
  predicate referenceIn(Raw::Name n, Raw::ExceptionHandler h, Raw::BasicDecl entity) {
    inHandler(n, h) and
    not n instanceof Raw::CallExpr and
    not n = any(Raw::DottedName d).getSuffix() and
    exists(Raw::BasicDecl d | d = n.getReferencedDecl() |
      d = entity or d.getUltimateDecl() = entity
    )
  }

  /** Holds if `call` is an entry call statement (`T.Start;`, `PO.Seize (X);`). */
  predicate isEntryCall(Raw::CallStmt call) {
    exists(Raw::Name callee | callee = [call.getCall(), call.getCall().(Raw::CallExpr).getName()] |
      callee.getReferencedDecl() instanceof Raw::EntryDecl
      or
      callee.(Raw::DottedName).getSuffix().getReferencedDecl() instanceof Raw::EntryDecl
    )
  }

  /** `calls`: `call`, in handler `h`, is a subprogram call or an entry call statement. */
  predicate callIn(Raw::AdaNode call, Raw::ExceptionHandler h) {
    inHandler(call, h) and (call instanceof Call or isEntryCall(call))
  }

  /** `entry_calls`: `call`, in handler `h`, is an entry call. */
  predicate entryCallIn(Raw::CallStmt call, Raw::ExceptionHandler h) {
    inHandler(call, h) and isEntryCall(call)
  }
}
