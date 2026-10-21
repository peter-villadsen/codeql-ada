/**
 * AdaControl rule `Max_Nesting`: declarative constructs nested too deeply
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module MaxNesting {
  /** Holds if `n` declares a task: a task type or a single task, or is a task body. */
  private predicate isTask(Raw::AdaNode n) {
    n instanceof Raw::TaskTypeDecl and not n instanceof Raw::SingleTaskTypeDecl
    or
    n instanceof Raw::SingleTaskDecl
    or
    n instanceof Raw::TaskBody
  }

  /**
   * Holds if `n` is a declarative construct of `kind`: `all` for packages, subprogram
   * bodies, generics, tasks, protected units, entry bodies and blocks; `generic`; `task`.
   */
  predicate isConstruct(Raw::AdaNode n, string kind) {
    kind = "all" and
    (
      n instanceof Raw::BasePackageDecl and not n instanceof Raw::GenericPackageInternal
      or
      n instanceof Raw::PackageBody
      or
      n instanceof Raw::SubpBody
      or
      n instanceof Raw::GenericDecl
      or
      isTask(n)
      or
      n instanceof Raw::ProtectedTypeDecl
      or
      n instanceof Raw::SingleProtectedDecl
      or
      n instanceof Raw::ProtectedBody
      or
      n instanceof Raw::EntryBody
      or
      n instanceof Raw::BlockStmt
    )
    or
    kind = "generic" and n instanceof Raw::GenericDecl
    or
    kind = "task" and isTask(n)
  }

  /** Gets the nesting depth of construct `n` among constructs of `kind`: how many enclose it. */
  int depth(Raw::AdaNode n, string kind) {
    isConstruct(n, kind) and
    result = count(Raw::AdaNode outer | outer = n.getParent+() and isConstruct(outer, kind))
  }
}
