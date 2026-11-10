/**
 * AdaControl rule `Unnecessary_Use_Clause`: `use`, `use type` and `use all type`
 * clauses that are not needed, or that a narrower clause, or one elsewhere, would do
 * (`docs/adacontrol.md`).
 *
 * The scope of a clause (`inScopeOf`) is, for a context clause, the rest of its
 * compilation unit, the body of a spec and their subunits; for a declaration, the rest
 * of its declarative region, and the body of a package spec. Each name of a clause is
 * checked on its own. A *use* of a package is a name in the scope that resolves to a
 * declaration of its visible part; it is *direct* when it needs the clause (not a
 * selected component's selector), and an operator is used directly when an operand is
 * of a type of the package, since the operator is not visible otherwise. A use of a
 * type, for `use type`, is an operator with an operand of the type; for `use all
 * type`, also a direct use of a primitive operation or an enumeration literal of it.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.UseClauses
private import codeql.ada.adacontrol.WithClauses
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.Unresolved

module UnnecessaryUseClause {
  /** Holds if `a` starts after `b` ends, in the same file. */
  private predicate after(Raw::AdaNode a, Raw::AdaNode b) {
    exists(string f, int al, int ac, int bl, int bc |
      a.getLocation().hasLocationInfo(f, al, ac, _, _) and
      b.getLocation().hasLocationInfo(f, _, _, bl, bc)
    |
      al > bl or al = bl and ac > bc
    )
  }

  /** Holds if compilation unit `inner` is `cu`, its body, or a subunit of one, directly or not. */
  private predicate unitInScope(Raw::CompilationUnit cu, Raw::CompilationUnit inner) {
    exists(Raw::UseClause u | UseClauses::isGlobal(u) and cu = u.getEnclosingUnit()) and
    (
      inner = cu
      or
      WithClauses::specUnit(inner) = cu
      or
      exists(Raw::CompilationUnit parent |
        unitInScope(cu, parent) and
        inner.getBody().(Raw::Subunit).getName().getReferencedDecl().getEnclosingUnit() = parent
      )
    )
  }

  /** Gets the declarative region `u` is declared in, when it is not a context clause. */
  private Raw::AdaNode owner(Raw::UseClause u) {
    not UseClauses::isGlobal(u) and result = u.getParent().getParent().(Raw::DeclarativePart).getParent()
  }

  /** Gets the body of package spec `p`. */
  private Raw::PackageBody packageBody(Raw::BasePackageDecl p) {
    ada_body_part(p, result) or ada_body_part(p.getParent(), result)
  }

  /** Holds if `n` is in the scope of `u`. */
  predicate inScopeOf(Raw::AdaNode n, Raw::UseClause u) {
    UseClauses::isGlobal(u) and
    (
      n.getEnclosingUnit() = u.getEnclosingUnit() and after(n, u)
      or
      unitInScope(u.getEnclosingUnit(), n.getEnclosingUnit()) and
      n.getEnclosingUnit() != u.getEnclosingUnit()
    )
    or
    n.getParent+() = owner(u) and after(n, u)
    or
    n.getParent+() = packageBody(owner(u))
  }

  /** Holds if `n` is a name of a `with` or `use` clause, not a use of what it names. */
  private predicate inClause(Raw::AdaNode n) {
    n.getParent+() instanceof Raw::WithClause or n.getParent+() instanceof Raw::UseClause
  }

  /** Gets the package `name`, in a `use` clause, makes visible, through renamings. */
  Raw::BasePackageDecl usedPackage(Raw::Name name) {
    name = any(Raw::UsePackageClause u).getPackages().getChild(_) and
    exists(Raw::BasicDecl d | d = name.getReferencedDecl().getUltimateDecl() |
      result = d
      or
      result = d.(Raw::GenericPackageInstantiation).getDesignatedGeneric().(Raw::GenericPackageDecl).getPackageDecl()
    )
  }

  /** Gets the package spec whose visible part declares `d`, the innermost one. */
  private Raw::BasePackageDecl visibleIn(Raw::BasicDecl d) {
    exists(Raw::PublicPart pp |
      pp = result.getPublicPart() and
      d.getParent+() = pp and
      not exists(Raw::AdaNode inner |
        d.getParent+() = inner and
        inner.getParent+() = pp and
        (inner instanceof Raw::BasePackageDecl or inner instanceof Raw::BaseSubpBody or inner instanceof Raw::SubpSpec or inner instanceof Raw::ComponentList)
      )
    )
  }

  /**
   * Holds if `p` makes `d` visible: `d` is declared in its visible part, or is a child
   * unit of it (`use GNAT;` makes `Regpat` name `GNAT.Regpat`).
   */
  private predicate declares(Raw::BasePackageDecl p, Raw::BasicDecl d) {
    visibleIn(d) = p
    or
    d.getParent() instanceof Raw::LibraryItem and
    d.getQualifiedName().toLowerCase().regexpCapture("(.*)\\.[^.]+", 1) =
      p.getQualifiedName().toLowerCase()
  }

  /** Gets the simple name of `d`, in lower case: the last part of a child unit's name. */
  private string simpleName(Raw::BasicDecl d) {
    result = d.getAName().toLowerCase().regexpCapture("(.*\\.)?([^.]+)", 2)
  }

  /** Holds if `t`, or the type it is a subtype or view of, is declared in the visible part of `p`. */
  private predicate typeOf(Type t, Raw::BasePackageDecl p) {
    visibleIn(t) = p or visibleIn(t.getParentType+()) = p or
    exists(Type v | TypeCategories::sameType(t, v) | visibleIn(v) = p)
  }

  /** Holds if operator `op` (of an operation) has an operand of type `t`. */
  private predicate operandOf(Raw::Op op, Type t) {
    exists(Raw::Expr operand |
      operand = [op.getParent().(Raw::BinOp).getLeft(), op.getParent().(Raw::BinOp).getRight(), op.getParent().(Raw::UnOp).getExpr()]
    |
      operand.getType() = t
    )
  }

  /**
   * Holds if `r`, in the scope of `u`, uses package `p` (named in `u` by `name`);
   * `direct` says whether it needs the clause; `kind` is `operator`, `primitive` (a
   * subprogram or enumeration literal with a parameter, result or type of a type of
   * `p`) or `other`.
   */
  predicate usesPackage(Raw::UseClause u, Raw::Name name, Raw::AdaNode r, boolean direct, string kind) {
    exists(Raw::BasePackageDecl p | p = usedPackage(name) and name.getParent+() = u |
      inScopeOf(r, u) and
      not inClause(r) and
      (
        exists(Raw::BasicDecl d | d = r.(Raw::Name).getReferencedDecl() and declares(p, d) |
          not r instanceof Raw::Op and
          // `P.X` resolves as its selector `X` does: the selector is the use
          not r instanceof Raw::DottedName and
          (if r = any(Raw::DottedName dn).getSuffix() then direct = false else direct = true) and
          (
            if
              exists(Subprogram s, Type t | s = d and typeOf(t, p) |
                s.getAParameter().getType() = t or s.getReturnType() = t
              )
              or
              d instanceof Raw::EnumLiteralDecl
            then kind = "primitive"
            else kind = "other"
          )
        )
        or
        (
          exists(Type t | operandOf(r, t) and typeOf(t, p))
          or
          // an operator of the package on other types (`"/"` on strings)
          declares(p, r.(Raw::Op).getReferencedDecl())
        ) and
        direct = true and
        kind = "operator"
        or
        // a name that did not resolve, spelled like a declaration of `p`: maybe a use
        exists(Raw::BasicDecl d | declares(p, d) |
          Unresolved::identifier(r, simpleName(d))
        ) and
        not r = any(Raw::DottedName dn).getSuffix() and
        direct = true and
        kind = "other"
      )
    )
  }

  /** Gets the type `name`, in a `use type` or `use all type` clause, names. */
  Type usedType(Raw::Name name) {
    name = any(Raw::UseTypeClause u).getTypes().getChild(_) and result = name.getReferencedDecl()
  }

  /** Holds if `r`, in the scope of `u`, directly uses type `t` (named in `u` by `name`), as an operator or, for `use all type`, as a primitive. */
  predicate usesType(Raw::UseClause u, Raw::Name name, Raw::AdaNode r, string kind) {
    exists(Type t | t = usedType(name) and name.getParent+() = u |
      inScopeOf(r, u) and
      not inClause(r) and
      (
        exists(Type o | operandOf(r, o) | TypeCategories::sameType(o, t) or o.getParentType+() = t) and
        kind = "operator"
        or
        UseClauses::clauseKind(u) = "all_type" and
        not r = any(Raw::DottedName dn).getSuffix() and
        not r instanceof Raw::DottedName and
        exists(Raw::BasicDecl d | d = r.(Raw::Name).getReferencedDecl() |
          exists(Subprogram s | s = d | s.getAParameter().getType() = t or s.getReturnType() = t)
          or
          d = t.getAnEnumerationLiteral()
        ) and
        kind = "primitive"
      )
    )
  }

  /** Holds if `u`'s name `name` is already visible where `u` is: in the scope of another clause for it, or inside the package. */
  predicate nested(Raw::UseClause u, Raw::Name name) {
    exists(Raw::BasePackageDecl p | p = usedPackage(name) and name.getParent+() = u |
      // the same package, not another instance of the same generic
      exists(Raw::UseClause other, Raw::Name n2 |
        other != u and
        n2 = any(Raw::UsePackageClause c).getPackages().getChild(_) and
        n2.getReferencedDecl().getUltimateDecl() = name.getReferencedDecl().getUltimateDecl() and
        n2.getParent+() = other and
        inScopeOf(u, other)
      )
      or
      u.getParent+() = p
      or
      u.getParent+() = packageBody(p)
    )
    or
    exists(Type t | t = usedType(name) and name.getParent+() = u |
      exists(Raw::UseClause other, Raw::Name n2 |
        other != u and
        usedType(n2) = t and
        n2.getParent+() = other and
        inScopeOf(u, other) and
        UseClauses::clauseKind(other) = ["all_type", UseClauses::clauseKind(u)]
      )
      or
      exists(Raw::UseClause other, Raw::Name n2 |
        visibleIn(t) = usedPackage(n2) and n2.getParent+() = other and inScopeOf(u, other)
      )
    )
  }

  /** Holds if `u` is in a package spec: a context clause of a spec, or a declaration of one. */
  private predicate inSpec(Raw::UseClause u, Raw::AdaNode body) {
    UseClauses::isGlobal(u) and
    WithClauses::specUnit(body) = u.getEnclosingUnit()
    or
    body = packageBody(owner(u))
  }

  /**
   * Holds if the name `name` of clause `u` is not needed, for `subrule`: `unused`,
   * `qualified`, `operator`, `primitive`, `nested` or `movable`.
   */
  predicate unnecessary(Raw::UseClause u, Raw::Name name, string subrule) {
    u.fromSource() and
    name = UseClauses::aName(u) and
    (
      nested(u, name) and subrule = "nested"
      or
      not nested(u, name) and
      (
        exists(usedPackage(name)) and
        (
          not usesPackage(u, name, _, _, _) and subrule = "unused"
          or
          usesPackage(u, name, _, _, _) and
          not usesPackage(u, name, _, true, _) and
          subrule = "qualified"
          or
          usesPackage(u, name, _, true, _) and
          not usesPackage(u, name, _, true, ["primitive", "other"]) and
          subrule = "operator"
          or
          usesPackage(u, name, _, true, "primitive") and
          not usesPackage(u, name, _, true, "other") and
          subrule = "primitive"
          or
          exists(Raw::AdaNode body | inSpec(u, body) |
            usesPackage(u, name, _, true, _) and
            forall(Raw::AdaNode r | usesPackage(u, name, r, true, _) | r.getParent*() = body or r.getEnclosingUnit() = body)
          ) and
          subrule = "movable"
        )
        or
        exists(usedType(name)) and
        (
          not usesType(u, name, _, _) and subrule = "unused"
          or
          UseClauses::clauseKind(u) = "all_type" and
          usesType(u, name, _, _) and
          not usesType(u, name, _, "primitive") and
          subrule = "operator"
        )
      )
    )
  }
}
