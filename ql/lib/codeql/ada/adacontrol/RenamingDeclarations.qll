/**
 * AdaControl rule `Renaming_Declarations`: renaming declarations, by kind, by filter and
 * by place (`Places::isAt`) (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module RenamingDeclarations {
  /** Gets the name renamed by renaming declaration `d`. */
  Raw::Name renamedName(Raw::BasicDecl d) {
    result =
      [
        d.(Raw::ObjectDecl).getRenamingClause().getRenamedObject(),
        d.(Raw::ExceptionDecl).getRenames().getRenamedObject(),
        d.(Raw::PackageRenamingDecl).getRenames().getRenamedObject(),
        d.(Raw::SubpRenamingDecl).getRenames().getRenamedObject(),
        d.(Raw::GenericPackageRenamingDecl).getRenames().getRenamedObject(),
        d.(Raw::GenericSubpRenamingDecl).getRenames().getRenamedObject()
      ]
  }

  /** Holds if `d` is a renaming declaration. */
  predicate isRenaming(Raw::BasicDecl d) { exists(renamedName(d)) }

  /** Gets the declaration `d` renames, if it resolves. */
  Raw::BasicDecl renamed(Raw::BasicDecl d) {
    result = renamedName(d).getReferencedDecl()
    or
    not exists(renamedName(d).getReferencedDecl()) and
    result = renamedName(d).(Raw::DottedName).getSuffix().getReferencedDecl()
  }

  /**
   * Gets the kind of renaming `d`, as AdaControl names it: `object`, `function_call` (an
   * object renaming of a function call), `procedure`, `function`, `package`, `exception`;
   * generic renamings are `package`, `procedure` or `function`.
   */
  string kind(Raw::BasicDecl d) {
    isRenaming(d) and
    (
      exists(d.(Raw::ObjectDecl).getRenamingClause()) and
      if renamedName(d) instanceof Raw::CallExpr or renamed(d) instanceof Raw::BaseSubpBody or renamed(d) instanceof Raw::ClassicSubpDecl
      then result = "function_call"
      else result = "object"
      or
      d instanceof Raw::ExceptionDecl and result = "exception"
      or
      (d instanceof Raw::PackageRenamingDecl or d instanceof Raw::GenericPackageRenamingDecl) and
      result = "package"
      or
      d.(Raw::SubpRenamingDecl).getSubpSpec().getSubpKind() instanceof Raw::SubpKindProcedure and
      result = "procedure"
      or
      d.(Raw::SubpRenamingDecl).getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
      result = "function"
      or
      d.(Raw::GenericSubpRenamingDecl).getKind() instanceof Raw::SubpKindProcedure and
      result = "procedure"
      or
      d.(Raw::GenericSubpRenamingDecl).getKind() instanceof Raw::SubpKindFunction and
      result = "function"
    )
  }

  /** Gets the simple name of `n`: its last component. */
  private string simpleName(Raw::Name n) {
    result = n.getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase()
  }

  /**
   * Holds if filter `filter` applies to renaming `d`: `identical`, `generic`, `as_body`,
   * `operator`, `as_operator`, `synonym`, `library_unit`, `renaming`.
   */
  predicate hasFilter(Raw::BasicDecl d, string filter) {
    isRenaming(d) and
    (
      filter = "identical" and simpleName(renamedName(d)) = d.getAName().toLowerCase()
      or
      filter = "generic" and
      (
        renamed(d) instanceof Raw::GenericDecl or
        d instanceof Raw::GenericPackageRenamingDecl or
        d instanceof Raw::GenericSubpRenamingDecl
      )
      or
      filter = "as_body" and d instanceof Raw::SubpRenamingDecl and ada_body_part(_, d)
      or
      filter = "operator" and simpleName(renamedName(d)).matches("\"%\"")
      or
      filter = "as_operator" and d.getAName().matches("\"%\"")
      or
      // a synonym is a second name for the entity: not a function call's result, nor a
      // renaming as body, which completes a declaration rather than adding a name
      filter = "synonym" and
      renamed(d).getParent() = d.getParent() and
      not kind(d) = "function_call" and
      not ada_body_part(_, d)
      or
      filter = "library_unit" and renamed(d).getParent() instanceof Raw::LibraryItem
      or
      filter = "renaming" and isRenaming(renamed(d))
    )
  }
}
