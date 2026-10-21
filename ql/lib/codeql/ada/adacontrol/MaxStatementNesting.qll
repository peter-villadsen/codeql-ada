/**
 * AdaControl rule `Max_Statement_Nesting`: compound statements nested too deeply
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module MaxStatementNesting {
  /**
   * Holds if `s` is a compound statement of `kind`: `block`, `case`, `if`, `loop`, and
   * `all` for any compound statement.
   */
  predicate isCompound(Raw::Stmt s, string kind) {
    s instanceof Raw::BlockStmt and kind = ["block", "all"]
    or
    s instanceof Raw::CaseStmt and kind = ["case", "all"]
    or
    s instanceof Raw::IfStmt and kind = ["if", "all"]
    or
    s instanceof Raw::BaseLoopStmt and kind = ["loop", "all"]
    or
    (
      s instanceof Raw::SelectStmt or
      s instanceof Raw::AcceptStmtWithStmts or
      s instanceof Raw::ExtendedReturnStmt
    ) and
    kind = "all"
  }

  /** Gets the innermost body (subprogram, task, entry, package) around statement `s`. */
  private Raw::BodyNode body(Raw::AdaNode s) {
    result = s.getParent+() and
    not exists(Raw::BodyNode inner | inner = s.getParent+() and inner.getParent+() = result)
  }

  /**
   * Gets the nesting depth of compound statement `s` among those of `kind` within its
   * body: 1 for an outermost one.
   */
  int depth(Raw::Stmt s, string kind) {
    isCompound(s, kind) and
    result =
      1 +
        count(Raw::Stmt outer |
          outer = s.getParent+() and isCompound(outer, kind) and outer.getParent+() = body(s)
        )
  }
}
