/**
 * AdaControl rule `Use_Clauses`: `use`, `use type` and `use all type` clauses, in context
 * clauses or among declarations, except for given packages or types
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module UseClauses {
  /** Gets the kind of use clause `u`: `package`, `type` or `all_type`. */
  string clauseKind(Raw::UseClause u) {
    u instanceof Raw::UsePackageClause and result = "package"
    or
    u instanceof Raw::UseTypeClause and
    if u.(Raw::UseTypeClause).getHasAll() instanceof Raw::AllPresent
    then result = "all_type"
    else result = "type"
  }

  /** Holds if `u` is a context clause (`global`, with the `with` clauses), not a declaration (`local`). */
  predicate isGlobal(Raw::UseClause u) { u.getParent().getParent() instanceof Raw::CompilationUnit }

  /** Gets a name `u` makes visible: a package of a `use`, a type of a `use type`. */
  Raw::Name aName(Raw::UseClause u) {
    result = [u.(Raw::UsePackageClause).getPackages(), u.(Raw::UseTypeClause).getTypes()].getChild(_)
  }

  /**
   * Holds if `u`'s name `n` is controlled by the subrule `subrule` (`package`, `global`,
   * `local`, `type`, `type_global`, `type_local`, `all_type`, `all_type_global`,
   * `all_type_local`).
   */
  predicate controlled(Raw::UseClause u, Raw::Name n, string subrule) {
    n = aName(u) and
    exists(string kind | kind = clauseKind(u) |
      kind = "package" and
      (
        subrule = "package"
        or
        isGlobal(u) and subrule = "global"
        or
        not isGlobal(u) and subrule = "local"
      )
      or
      kind = ["type", "all_type"] and
      (
        subrule = kind
        or
        isGlobal(u) and subrule = kind + "_global"
        or
        not isGlobal(u) and subrule = kind + "_local"
      )
    )
  }
}
