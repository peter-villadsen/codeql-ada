/**
 * AdaControl rule `Return_Statements`: the nesting depth of return statements and their
 * number, in the regular statements and in each exception handler of callable entities
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module ReturnStatements {
  /** Holds if `r` is a return statement, simple or extended. */
  predicate isReturn(Raw::Stmt r) { r instanceof Raw::ReturnStmt or r instanceof Raw::ExtendedReturnStmt }

  /** Holds if `c` is a callable body: a subprogram body, an entry body, an accept statement. */
  private predicate isCallable(Raw::AdaNode c) {
    c instanceof Raw::SubpBody or c instanceof Raw::EntryBody or c instanceof Raw::AcceptStmtWithStmts
  }

  /** Gets the callable body that return statement `r` returns from. */
  Raw::AdaNode callable(Raw::Stmt r) {
    isReturn(r) and
    result = r.getParent+() and
    isCallable(result) and
    not exists(Raw::AdaNode inner | inner = r.getParent+() and isCallable(inner) and inner.getParent+() = result)
  }

  /** Gets the kind of callable `c`: `procedure`, `function` or `entry` (entry bodies and accepts). */
  string callableKind(Raw::AdaNode c) {
    c.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindProcedure and
    result = "procedure"
    or
    c.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
    result = "function"
    or
    (c instanceof Raw::EntryBody or c instanceof Raw::AcceptStmtWithStmts) and result = "entry"
  }

  /** Holds if `s` is a compound statement, for `depth`. */
  private predicate isCompound(Raw::AdaNode s) { s instanceof Raw::CompositeStmt and not s instanceof Raw::NamedStmt }

  /**
   * `depth`: the number of compound statements around return statement `r` in its
   * callable, blocks included: 0 directly in the callable's statements.
   */
  int depth(Raw::Stmt r) {
    exists(Raw::AdaNode c | c = callable(r) |
      result =
        count(Raw::AdaNode s | s = r.getParent+() and isCompound(s) and s.getParent+() = c and not s = c)
    )
  }

  /**
   * Gets the exception handler whose return statements `r` is counted with: the innermost
   * handler around it within its callable, if any.
   */
  Raw::ExceptionHandler handler(Raw::Stmt r) {
    result = r.getParent+() and
    result.getParent+() = callable(r) and
    not exists(Raw::ExceptionHandler inner |
      inner = r.getParent+() and inner.getParent+() = result
    )
  }

  /** `regular_count`: the number of return statements in the regular statements of callable `c`. */
  int regularCount(Raw::AdaNode c) {
    isCallable(c) and
    result = count(Raw::Stmt r | callable(r) = c and not exists(handler(r)))
  }

  /** `handler_count`: the number of return statements in exception handler `h` of callable `c`. */
  int handlerCount(Raw::AdaNode c, Raw::ExceptionHandler h) {
    h.getParent+() = c and
    isCallable(c) and
    not exists(Raw::AdaNode inner | inner = h.getParent+() and isCallable(inner) and inner.getParent+() = c) and
    result = count(Raw::Stmt r | callable(r) = c and handler(r) = h)
  }
}
