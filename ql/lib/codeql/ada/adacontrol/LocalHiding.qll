/**
 * AdaControl rule `Local_Hiding`: declarations that hide (or overload) a declaration of
 * the same name in an enclosing declarative region (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module LocalHiding {
  /**
   * Holds if `r` is a declarative region: a package (spec and body are one region), a
   * subprogram, task, entry or protected body, or a block.
   */
  private predicate isRegion(Raw::AdaNode r) {
    r instanceof Raw::BasePackageDecl or
    r instanceof Raw::PackageBody or
    r instanceof Raw::SubpBody or
    r instanceof Raw::ExprFunction or
    r instanceof Raw::TaskBody or
    r instanceof Raw::EntryBody or
    r instanceof Raw::ProtectedBody or
    r instanceof Raw::BlockStmt or
    r instanceof Raw::BaseLoopStmt or
    r instanceof Raw::GenericDecl
  }

  /** Gets the region `r` is part of: a package body's region is its spec's. */
  private Raw::AdaNode canonical(Raw::AdaNode r) {
    isRegion(r) and
    (
      exists(Raw::BasicDecl spec | ada_body_part(spec, r) and r instanceof Raw::PackageBody |
        result = spec
      )
      or
      not (r instanceof Raw::PackageBody and ada_body_part(_, r)) and result = r
    )
  }

  /** Gets the region that most closely encloses node `n` (not `n` itself). */
  private Raw::AdaNode enclosingRegion(Raw::AdaNode n) {
    exists(Raw::AdaNode p | p = n.getParent() |
      isRegion(p) and result = canonical(p)
      or
      not isRegion(p) and result = enclosingRegion(p)
    )
  }

  /** Gets the region enclosing region `r`, a package body seen through its spec. */
  private Raw::AdaNode outerRegion(Raw::AdaNode r) {
    exists(Raw::AdaNode syntactic | canonical(syntactic) = r | result = enclosingRegion(syntactic))
  }

  /** Gets the family of declaration `d`, as AdaControl's `not_different_families` means it. */
  string family(Raw::BasicDecl d) {
    (
      d instanceof Raw::ObjectDecl or
      d instanceof Raw::NumberDecl or
      d instanceof Raw::ParamSpec or
      d instanceof Raw::ForLoopVarDecl
    ) and
    result = "data"
    or
    d instanceof Raw::BaseTypeDecl and result = "type"
    or
    (
      d instanceof Raw::BasicSubpDecl and not d instanceof Raw::GenericSubpInternal
      or
      d instanceof Raw::BaseSubpBody
      or
      d instanceof Raw::SubpBodyStub
    ) and
    result = "subprogram"
    or
    (d instanceof Raw::BasePackageDecl or d instanceof Raw::PackageBody) and
    not d instanceof Raw::GenericPackageInternal and
    result = "package"
    or
    d instanceof Raw::GenericDecl and result = "generic"
    or
    d instanceof Raw::ExceptionDecl and result = "exception"
    or
    (d instanceof Raw::LabelDecl or d instanceof Raw::NamedStmtDecl) and result = "label"
  }

  /**
   * Holds if `d` declares `name` (lower-cased) in region `r`. The parameters of a
   * subprogram body are in the body's region (a spec's parameters hide nothing); a loop
   * variable is in its loop's. A completion (a body, a subunit) declares nothing new.
   */
  private predicate declares(Raw::BasicDecl d, string name, Raw::AdaNode r) {
    exists(family(d)) and
    name = d.getAName().toLowerCase() and
    (
      exists(Raw::BaseSubpBody body | d.getParent+() = body.getSubpSpec() |
        d instanceof Raw::ParamSpec and r = canonical(body)
      )
      or
      d instanceof Raw::ForLoopVarDecl and r = canonical(d.getParent().getParent())
      or
      not d instanceof Raw::ParamSpec and
      not d instanceof Raw::ForLoopVarDecl and
      not ada_body_part(_, d) and
      not d.getParent() instanceof Raw::Subunit and
      r = enclosingRegion(d)
    )
  }

  /** Holds if `d` is a subprogram or an enumeration literal: something that can be overloaded. */
  predicate isOverloadable(Raw::BasicDecl d) {
    family(d) = "subprogram"
  }

  /** Holds if `d` declares an operator (`"+"`). */
  predicate isOperator(Raw::BasicDecl d) { d.getAName().matches("\"%\"") }

  /** Holds if `d` renames something of the same name (`procedure Put renames Pkg.Put;`). */
  predicate isIdenticalRenaming(Raw::BasicDecl d) {
    exists(Raw::Name renamed |
      renamed =
        [
          d.(Raw::SubpRenamingDecl).getRenames().getRenamedObject(),
          d.(Raw::PackageRenamingDecl).getRenames().getRenamedObject(),
          d.(Raw::ObjectDecl).getRenamingClause().getRenamedObject(),
          d.(Raw::ExceptionDecl).getRenames().getRenamedObject()
        ]
    |
      renamed.getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase() = d.getAName().toLowerCase()
    )
  }

  /**
   * Holds if declaration `inner` has the name of declaration `outer`, declared in a region
   * enclosing `inner`'s.
   */
  predicate sameNameOuter(Raw::BasicDecl inner, Raw::BasicDecl outer) {
    exists(string name, Raw::AdaNode r, Raw::AdaNode outerR |
      declares(inner, name, r) and
      declares(outer, name, outerR) and
      outerR = outerRegion+(r)
    )
  }

  /**
   * `strict`: `inner` hides `outer`, the nearest declaration of the same name in an
   * enclosing region; not when both are subprograms (overloading). The exceptions
   * `not_operator`, `not_enumeration`, `not_identical_renaming` and
   * `not_different_families` are `isOperator`, `Raw::EnumLiteralDecl`,
   * `isIdenticalRenaming` and `family` in your query.
   */
  predicate hides(Raw::BasicDecl inner, Raw::BasicDecl outer) {
    sameNameOuter(inner, outer) and
    not (isOverloadable(inner) and isOverloadable(outer)) and
    // the nearest one: not one hidden by a declaration `inner` hides
    not exists(Raw::BasicDecl mid | sameNameOuter(inner, mid) and sameNameOuter(mid, outer))
  }

  /**
   * `overloading`: subprogram (or enumeration literal) `inner` overloads `outer`, of the
   * same name, in the same region or an enclosing one.
   */
  predicate overloads(Raw::BasicDecl inner, Raw::BasicDecl outer) {
    isOverloadable(inner) and
    isOverloadable(outer) and
    (
      sameNameOuter(inner, outer)
      or
      exists(string name, Raw::AdaNode r |
        declares(inner, name, r) and
        declares(outer, name, r) and
        inner != outer and
        inner.getLocation().getStartLine() > outer.getLocation().getStartLine()
      )
    )
  }
}
