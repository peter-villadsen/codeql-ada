/**
 * AdaControl rule `Dependencies`: the units a compilation unit depends on through its
 * `with` clauses, against a list of allowed or forbidden units or by count
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module Dependencies {
  /** Gets the unit (spec, body or subunit) compilation unit `cu` declares. */
  Raw::BasicDecl unitOf(Raw::CompilationUnit cu) {
    result = cu.getBody().(Raw::LibraryItem).getItem() or
    result = cu.getBody().(Raw::Subunit).getBody()
  }

  /** Gets the full name of the unit `cu` declares, as written (`A.B.C`). */
  string unitName(Raw::CompilationUnit cu) {
    result = unitOf(cu).getADefiningName().getName().getText()
  }

  /** Gets a name in a `with` clause of `cu`, each unit of `with A, B;` separately. */
  Raw::Name aWithName(Raw::CompilationUnit cu) {
    result = cu.getPrelude().getChild(_).(Raw::WithClause).getPackages().getChild(_)
  }

  /**
   * Gets a unit `withName` denotes: the declaration it resolves to, what that renames,
   * and the generic it is an instance of.
   */
  Raw::BasicDecl withedUnit(Raw::Name withName) {
    withName = aWithName(_) and
    exists(Raw::BasicDecl d | d = withName.getReferencedDecl() |
      result = d or
      result = d.getUltimateDecl() or
      result = d.(Raw::GenericInstantiation).getDesignatedGeneric()
    )
  }

  /**
   * `with`: `withName`, in a `with` clause of `cu`, names `unit` (through renamings and
   * instantiations).
   */
  predicate withOf(Raw::CompilationUnit cu, Raw::Name withName, Raw::BasicDecl unit) {
    withName = aWithName(cu) and unit = withedUnit(withName)
  }

  /** Holds if unit `d` is a private child (`private package P.C is ...`). */
  predicate isPrivateUnit(Raw::BasicDecl d) {
    d.getParent().(Raw::LibraryItem).getHasPrivate() instanceof Raw::PrivatePresent
  }

  /**
   * `public_child` and `private_child`: `cu` withs `withName`, a child unit of its own
   * (`with P.C;` in `P` or its body), which is private when `isPrivate` holds.
   */
  predicate dependsOnOwnChild(Raw::CompilationUnit cu, Raw::Name withName, boolean isPrivate) {
    withName = aWithName(cu) and
    withName.getText().toLowerCase().matches(unitName(cu).toLowerCase() + ".%") and
    if isPrivateUnit(withName.getReferencedDecl()) then isPrivate = true
    else isPrivate = false
  }

  /** `raw`: the number of names in the `with` clauses of `cu`, repeats counted. */
  int rawCount(Raw::CompilationUnit cu) {
    exists(unitOf(cu)) and result = count(aWithName(cu))
  }

  /** Gets a unit `cu` depends on through a `with` clause, by name, a child's parents included. */
  private string directUnit(Raw::CompilationUnit cu) {
    exists(string full | full = aWithName(cu).getText().toLowerCase() |
      result = full
      or
      exists(int i | result = full.prefix(i) and full.charAt(i) = ".")
    )
  }

  /** `direct`: the number of different units `cu` depends on, the parents of a child unit included. */
  int directCount(Raw::CompilationUnit cu) {
    exists(unitOf(cu)) and result = count(directUnit(cu))
  }

  /** `parent`: the number of parents of the unit of `cu` (0 for a root unit). */
  int parentCount(Raw::CompilationUnit cu) {
    result = count(int i | unitName(cu).charAt(i) = ".")
  }
}
