/**
 * AdaControl rule `Unsafe_Elaboration`: library packages, generic or not, whose
 * elaboration calls a subprogram, or instantiates a generic, of another unit that is
 * not language-defined, without `pragma Elaborate` or `Elaborate_All` for that unit:
 * whether its body is elaborated first depends on the elaboration order the binder
 * picks (`docs/adacontrol.md`).
 *
 * The elaboration of a package is its elaboration code
 * (`NotElaborationCalls::isElaborationCode`) in its spec and body, and, as in
 * AdaControl, the bodies of its tasks, which start during elaboration. Calls of the
 * package's own subprograms are followed to their bodies; a call or instantiation of
 * another unit's is reported, without following it further.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.adacontrol.Dependencies
private import codeql.ada.adacontrol.GlobalReferences
private import codeql.ada.adacontrol.NotElaborationCalls

module UnsafeElaboration {
  /**
   * Gets the library unit declared by compilation unit `cu`, by its spec: the spec of
   * a body, and the parent unit of a subunit.
   */
  Raw::BasicDecl libraryUnit(Raw::CompilationUnit cu) {
    exists(Raw::BasicDecl u | u = Dependencies::unitOf(cu) and cu.getBody() instanceof Raw::LibraryItem |
      ada_body_part(result, u) and result.getParent() instanceof Raw::LibraryItem
      or
      not exists(Raw::BasicDecl spec | ada_body_part(spec, u) and spec.getParent() instanceof Raw::LibraryItem) and
      result = u
    )
    or
    result = libraryUnit(cu.getBody().(Raw::Subunit).getName().getReferencedDecl().getEnclosingUnit())
  }

  /** Gets the library unit `n` is in. */
  Raw::BasicDecl unitOf(Raw::AdaNode n) { result = libraryUnit(n.getEnclosingUnit()) }

  /** Holds if unit `u` is language-defined: `Ada`, `System`, `Interfaces` or a child of one. */
  predicate isLanguageDefined(Raw::BasicDecl u) {
    u.getQualifiedName().toLowerCase().regexpMatch("(ada|system|interfaces)(\\..*)?")
  }

  /** Holds if `p` is a library package, generic or not, the rule checks. */
  predicate isLibraryPackage(Raw::BasicDecl p) {
    p.getParent() instanceof Raw::LibraryItem and
    (p instanceof Raw::BasePackageDecl or p instanceof Raw::GenericPackageDecl)
  }

  /** Holds if `n` runs while package `p` is elaborated: elaboration code of `p`, or in one of its task bodies. */
  private predicate inElaboration(Raw::BasicDecl p, Raw::AdaNode n) {
    isLibraryPackage(p) and
    unitOf(n) = p and
    (
      NotElaborationCalls::isElaborationCode(n)
      or
      exists(Raw::TaskBody t | t = GlobalReferences::bodyOf(n) | NotElaborationCalls::isElaborationCode(t))
    )
  }

  /** Holds if body `b`, of a subprogram of `p`, may run while `p` is elaborated. */
  private predicate reachedBody(Raw::BasicDecl p, Raw::AdaNode b) {
    exists(Call c |
      (
        inElaboration(p, c)
        or
        exists(Raw::AdaNode caller | reachedBody(p, caller) and GlobalReferences::bodyOf(c) = caller)
      ) and
      b = c.getTarget().getBody() and
      unitOf(b) = p
    )
  }

  /** Holds if `n` runs while `p` is elaborated, directly or in a subprogram of `p` it calls. */
  predicate runsDuringElaboration(Raw::BasicDecl p, Raw::AdaNode n) {
    inElaboration(p, n)
    or
    reachedBody(p, GlobalReferences::bodyOf(n))
  }

  /** Gets the unit whose subprogram call `c` calls, or whose generic instantiation `c` instantiates. */
  Raw::BasicDecl usedUnit(Raw::AdaNode c) {
    result = unitOf(c.(Call).getTarget())
    or
    result = unitOf(c.(Raw::GenericInstantiation).getDesignatedGeneric())
  }

  /** Holds if a `pragma Elaborate` or `Elaborate_All` of the spec or body of `p` names unit `u`. */
  predicate hasElaboratePragma(Raw::BasicDecl p, Raw::BasicDecl u) {
    exists(Raw::PragmaNode pr, Raw::Name arg |
      pr.getParent().getParent() = any(Raw::CompilationUnit cu | libraryUnit(cu) = p) and
      pr.getId().getText().toLowerCase() = ["elaborate", "elaborate_all"] and
      arg = pr.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr()
    |
      arg.getReferencedDecl() = u or
      arg.getReferencedDecl().getUltimateDecl() = u or
      arg.getText().toLowerCase() = u.getQualifiedName().toLowerCase()
    )
  }

  /**
   * Holds if the elaboration of package `p` calls a subprogram, or instantiates a
   * generic, of unit `u` (at `site`), which is not language-defined and is not named
   * by a `pragma Elaborate` or `Elaborate_All` of `p`.
   */
  predicate unsafe(Raw::BasicDecl p, Raw::BasicDecl u, Raw::AdaNode site) {
    runsDuringElaboration(p, site) and
    u = usedUnit(site) and
    u != p and
    not isLanguageDefined(u) and
    not hasElaboratePragma(p, u)
  }
}
