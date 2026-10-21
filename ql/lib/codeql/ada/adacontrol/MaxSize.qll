/**
 * AdaControl rule `Max_Size`: statements, declarations and units too long in source
 * lines (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module MaxSize {
  /** Gets the number of source lines `n` spans. */
  int lines(Raw::AdaNode n) {
    result = n.getLocation().getEndLine() - n.getLocation().getStartLine() + 1
  }

  /** Holds if statement `n` has a name (`Outer : loop`, `Work : declare`). */
  private predicate isNamed(Raw::AdaNode n) { n.getParent() instanceof Raw::NamedStmt }

  /**
   * Holds if `n` is an element of AdaControl kind `kind`. For `if_branch` and
   * `case_branch` the element is the statements of the branch.
   */
  predicate isElement(Raw::AdaNode n, string kind) {
    n instanceof Raw::AcceptStmtWithStmts and kind = "accept"
    or
    n instanceof Raw::BlockStmt and kind = "block"
    or
    n instanceof Raw::BeginBlock and kind = "simple_block"
    or
    n instanceof Raw::BlockStmt and not isNamed(n) and kind = "unnamed_block"
    or
    n instanceof Raw::BaseLoopStmt and kind = "loop"
    or
    n instanceof Raw::BaseLoopStmt and not isNamed(n) and kind = "unnamed_loop"
    or
    n instanceof Raw::IfStmt and kind = "if"
    or
    n instanceof Raw::CaseStmt and kind = "case"
    or
    kind = "if_branch" and
    n =
      [
        any(Raw::IfStmt i).getThenStmts(), any(Raw::ElsifStmtPart e).getStmts(),
        any(Raw::IfStmt i).getElsePart().getStmts()
      ]
    or
    kind = "case_branch" and n = any(Raw::CaseStmtAlternative a).getStmts()
    or
    n instanceof Raw::BasePackageDecl and
    not n instanceof Raw::GenericPackageInternal and
    kind = "package_spec"
    or
    n instanceof Raw::PackageBody and kind = "package_body"
    or
    n.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindProcedure and
    kind = "procedure_body"
    or
    n.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
    kind = "function_body"
    or
    (n instanceof Raw::ProtectedTypeDecl or n instanceof Raw::SingleProtectedDecl) and
    kind = "protected_spec"
    or
    n instanceof Raw::ProtectedBody and kind = "protected_body"
    or
    n instanceof Raw::EntryBody and kind = "entry_body"
    or
    (
      n instanceof Raw::TaskTypeDecl and not n instanceof Raw::SingleTaskTypeDecl
      or
      n instanceof Raw::SingleTaskDecl
    ) and
    kind = "task_spec"
    or
    n instanceof Raw::TaskBody and kind = "task_body"
    or
    n instanceof Raw::CompilationUnit and kind = "unit"
  }
}
