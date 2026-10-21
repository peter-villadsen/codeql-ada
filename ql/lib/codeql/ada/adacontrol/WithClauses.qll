/**
 * AdaControl rule `With_Clauses`: `with` clauses that name several units, are redundant,
 * could be moved to the body or made `private`, units relied on through a parent's `with`,
 * and `limited`/`private` `with` clauses (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Dependencies

module WithClauses {
  /** `multiple_names`: `w` names more than one unit (`with A, B;`). */
  predicate hasMultipleNames(Raw::WithClause w) { exists(w.getPackages().getChild(1)) }

  /** `limited`, `private`, `limited_private`: the kind of `with` clause `w`, `regular` otherwise. */
  string withKind(Raw::WithClause w) {
    if w.getHasLimited() instanceof Raw::LimitedPresent
    then
      if w.getHasPrivate() instanceof Raw::PrivatePresent
      then result = "limited_private"
      else result = "limited"
    else
      if w.getHasPrivate() instanceof Raw::PrivatePresent
      then result = "private"
      else result = "regular"
  }

  /** Gets the unit `withName` names, through renamings, lower-cased by full name. */
  private string unitKey(Raw::Name withName) {
    withName = Dependencies::aWithName(_) and
    (
      result = Dependencies::withedUnit(withName).getQualifiedName().toLowerCase() and
      not Dependencies::withedUnit(withName) instanceof Raw::GenericInstantiation
      or
      not exists(Dependencies::withedUnit(withName)) and result = withName.getText().toLowerCase()
    )
  }

  /** Gets the compilation unit of the spec of the unit `cu` is the body of, if any. */
  Raw::CompilationUnit specUnit(Raw::CompilationUnit cu) {
    exists(Raw::BasicDecl spec |
      ada_body_part(spec, Dependencies::unitOf(cu)) and
      result = spec.getEnclosingUnit()
    )
  }

  /**
   * `reduceable`, redundant: `withName` in `cu` names a unit already withed by `earlier`:
   * an earlier name in `cu`, a `with` of the spec of `cu`, or `cu`'s own ancestor.
   */
  predicate isRedundant(Raw::CompilationUnit cu, Raw::Name withName, Raw::Name earlier) {
    withName = Dependencies::aWithName(cu) and
    (
      // twice in the same unit
      earlier = Dependencies::aWithName(cu) and
      earlier != withName and
      unitKey(earlier) = unitKey(withName) and
      earlier.getLocation().getStartLine() < withName.getLocation().getStartLine()
      or
      // in the spec and again in the body
      earlier = Dependencies::aWithName(specUnit(cu)) and
      unitKey(earlier) = unitKey(withName) and
      Dependencies::withedUnit(earlier).getParent() instanceof Raw::LibraryItem and
      not withName.getParent().getParent().(Raw::WithClause).getHasPrivate() instanceof Raw::PrivatePresent and
      not earlier.getParent().getParent().(Raw::WithClause).getHasLimited() instanceof Raw::LimitedPresent
    )
  }

  /** `reduceable`, an ancestor: `withName` in `cu` names an ancestor unit of `cu` (always visible). */
  predicate withsAncestor(Raw::CompilationUnit cu, Raw::Name withName) {
    withName = Dependencies::aWithName(cu) and
    Dependencies::unitName(cu).toLowerCase().matches(withName.getText().toLowerCase() + ".%")
  }

  /** Holds if name `n` (not in a context clause) refers to something declared in unit `unitCu`. */
  private predicate refersInto(Raw::Name n, Raw::CompilationUnit unitCu) {
    not n.getParent+() instanceof Raw::WithClause and
    not n.getParent+() instanceof Raw::UseClause and
    exists(Raw::BasicDecl d | d = n.getReferencedDecl() | d.getEnclosingUnit() = unitCu)
  }

  /** Gets the compilation unit of the spec `withName` names. */
  private Raw::CompilationUnit withedCu(Raw::Name withName) {
    result = Dependencies::withedUnit(withName).getEnclosingUnit() and
    result.getBody().(Raw::LibraryItem).getItem() = Dependencies::withedUnit(withName)
  }

  /** Holds if some name in `cu` refers into the unit `withName` names; `inPrivate` restricts to the private part. */
  private predicate usedIn(Raw::CompilationUnit cu, Raw::Name withName, boolean inPrivate) {
    exists(Raw::Name n | n.getEnclosingUnit() = cu and refersInto(n, withedCu(withName)) |
      if n.getParent+() instanceof Raw::PrivatePart then inPrivate = true else inPrivate = false
    )
  }

  /**
   * `reduceable`, movable: `withName`, in the spec `cu`, names a unit the spec does not
   * use but its body does (`to = "body"`), or one only its private part uses
   * (`to = "private"`, a `private with`). Only when the withed unit's declaration resolves.
   */
  predicate isMovable(Raw::CompilationUnit cu, Raw::Name withName, string to) {
    withName = Dependencies::aWithName(cu) and
    exists(withedCu(withName)) and
    Dependencies::unitOf(cu) instanceof Raw::BasePackageDecl and
    withKind(withName.getParent().getParent()) = "regular" and
    (
      not usedIn(cu, withName, _) and
      exists(Raw::CompilationUnit body |
        specUnit(body) = cu and usedIn(body, withName, _)
      ) and
      to = "body"
      or
      usedIn(cu, withName, true) and not usedIn(cu, withName, false) and to = "private"
    )
  }

  /**
   * `inherited`: name `n` in child unit or subunit `cu` refers into unit `unitCu`, which `cu`
   * does not with itself, but a parent unit (or the spec of `cu`'s parent) does.
   */
  predicate inheritsWith(Raw::CompilationUnit cu, Raw::Name n, Raw::CompilationUnit unitCu) {
    n.getEnclosingUnit() = cu and
    // the whole name: not the prefix or the selector of a dotted name
    not n.getParent() instanceof Raw::DottedName and
    refersInto(n, unitCu) and
    unitCu != cu and
    not unitCu = specUnit(cu) and
    not exists(Raw::Name w | w = Dependencies::aWithName([cu, specUnit(cu)]) | withedCu(w) = unitCu) and
    exists(Raw::CompilationUnit parent, Raw::Name w |
      Dependencies::unitName(cu).toLowerCase().matches(Dependencies::unitName(parent).toLowerCase() + ".%") and
      w = Dependencies::aWithName([parent, specUnit(parent)]) and
      withedCu(w) = unitCu
    )
  }
}
