/**
 * AdaControl rule `Potentially_Blocking_Operations`: potentially blocking operations
 * (Ada RM 9.5.1) that a protected operation performs, directly or through the
 * subprograms it calls (`docs/adacontrol.md`).
 *
 * The operations are `delay`, `select`, `accept` and `abort` statements, entry calls,
 * the creation of a task (an object of a task type), and calls of potentially blocking
 * subprograms: those of the language-defined input-output packages (`Ada.Text_IO` and
 * its siblings, `Sequential_IO`, `Direct_IO`, `Streams.Stream_IO`), and those named
 * with the data extension `blockingSubprogram`. Calls are followed through
 * `Call.getTarget()` to the bodies in the database; as in AdaControl, calls through
 * access-to-subprogram values, dispatching calls and calls of generic formal
 * subprograms are not.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.GlobalReferences
private import codeql.ada.adacontrol.Settings
private import codeql.ada.adacontrol.TypeCategories

module PotentiallyBlockingOperations {
  /**
   * Holds if `s` is potentially blocking: a subprogram of a language-defined
   * input-output package, or one named with the data extension `blockingSubprogram`.
   */
  predicate isBlockingSubprogram(Subprogram s) {
    exists(string q | q = s.getQualifiedName().toLowerCase() |
      q.regexpMatch("ada\\.([a-z_]*_)?text_io\\..*") or
      q.regexpMatch("ada\\.(sequential|direct)_io\\..*") or
      q.matches("ada.streams.stream_io.%")
    )
    or
    exists(string name | blockingSubprogram(name) and s.hasQualifiedName(name))
  }

  /** Holds if `n` names the entry called by an entry call statement. */
  private predicate isEntryCall(Raw::Name n) {
    n = any(Raw::CallStmt s).getCall() and n.getReferencedDecl() instanceof Raw::EntryDecl
    or
    n = any(Raw::CallStmt s).getCall().(Raw::CallExpr).getName() and
    n.getReferencedDecl() instanceof Raw::EntryDecl
  }

  /**
   * Holds if `n` is a potentially blocking operation of kind `kind`, in a body
   * (`GlobalReferences::bodyOf(n)`).
   */
  predicate blockingOperation(Raw::AdaNode n, string kind) {
    exists(GlobalReferences::bodyOf(n)) and
    (
      n instanceof Raw::DelayStmt and kind = "delay statement"
      or
      n instanceof Raw::SelectStmt and kind = "select statement"
      or
      n instanceof Raw::AcceptStmt and kind = "accept statement"
      or
      n instanceof Raw::AbortStmt and kind = "abort statement"
      or
      isEntryCall(n) and kind = "entry call"
      or
      exists(Variable v |
        v.getDeclaration() = n and
        not v.isRenaming() and
        TypeCategories::category(v.getType(), true) = "task"
      ) and
      kind = "task creation"
      or
      exists(Call c | c = n and isBlockingSubprogram(c.getTarget())) and
      kind = "call of " + n.(Call).getTarget().getName()
    )
  }

  /** Gets the body of an operation (subprogram or entry) of protected body `p`. */
  Raw::AdaNode protectedOperation(Raw::ProtectedBody p) { result = GlobalReferences::rootBody(p) }

  /** Holds if body `b` is the body of protected operation `op`, or a body it calls, directly or not. */
  predicate reaches(Raw::AdaNode op, Raw::AdaNode b) {
    op = protectedOperation(_) and b = op
    or
    exists(Raw::AdaNode mid, Call c |
      reaches(op, mid) and GlobalReferences::bodyOf(c) = mid and b = c.getTarget().getBody()
    )
  }

  /**
   * Holds if protected operation `op`, of protected body `p`, performs potentially
   * blocking operation `n` (of `kind`), directly or through calls.
   */
  predicate blocking(Raw::ProtectedBody p, Raw::AdaNode op, Raw::AdaNode n, string kind) {
    op = protectedOperation(p) and
    blockingOperation(n, kind) and
    reaches(op, GlobalReferences::bodyOf(n))
  }
}
