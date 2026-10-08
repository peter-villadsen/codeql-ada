/**
 * @name Raising a predefined exception
 * @description Explicitly raising a language-defined exception (`Constraint_Error`,
 *              `Program_Error`, ...) is misleading: these exceptions are meant to signal
 *              that the run-time detected an erroneous condition, not to be raised by
 *              application code. GNATcheck: `raising_predefined_exceptions`.
 * @id ada/raise-predefined-exception
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability error-handling
 */

import ada

/** Gets the lower-cased simple names of the exceptions package `Standard` declares. */
private string predefinedException() {
  result = ["constraint_error", "program_error", "storage_error", "tasking_error", "numeric_error"]
}

/**
 * Holds if `n` denotes a predefined exception: semantically, through any renamings, to
 * the declaration in package `Standard` (D-026) -- so a user exception that happens to
 * be called `Constraint_Error` is not one. Only if `n` does not resolve (no GNAT
 * runtime at extraction) is its text used.
 */
private predicate isPredefinedException(Name n) {
  n.getReferencedDecl().getUltimateDecl().getQualifiedName().toLowerCase() =
    "standard." + predefinedException()
  or
  not exists(n.getReferencedDecl()) and
  n.getText().toLowerCase().regexpReplaceAll("^standard\\.", "") = predefinedException()
}

/** Gets ` (a renaming of X)` if `n` reaches its exception through a renaming, else "". */
private string renamingNote(Name n) {
  exists(BasicDecl d, BasicDecl u | d = n.getReferencedDecl() and u = d.getUltimateDecl() |
    if u = d then result = "" else result = " (a renaming of " + u.getQualifiedName() + ")"
  )
  or
  not exists(n.getReferencedDecl()) and result = ""
}

from RaiseStmt r, Name n
where
  n = r.getExceptionName() and
  isPredefinedException(n) and
  r.fromSource()
select r, "Explicit raise of predefined exception " + n.getText() + renamingNote(n) + "."
