/**
 * AdaControl rule `Units`: library units that no other unit withs (`unreferenced`)
 * (`docs/adacontrol.md`). AdaControl's `unchecked` (units withed but not analyzed) is a
 * property of the extraction, not of the code: the extractor's diagnostics report units
 * it could not find.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Dependencies

module Units {
  /** Holds if `d` is a library unit declaration: a spec, or a body without one. */
  predicate isLibraryUnit(Raw::BasicDecl d) {
    d.getParent() instanceof Raw::LibraryItem and
    not ada_body_part(_, d)
  }

  /**
   * `unreferenced`: library unit `d` is withed by no unit of the project (through
   * renamings and instances). A child unit counts as a use of its parent (it names it).
   */
  predicate isUnreferenced(Raw::BasicDecl d) {
    isLibraryUnit(d) and
    not exists(Raw::Name w | w = Dependencies::aWithName(_) |
      Dependencies::withedUnit(w) = d
      or
      // `with P.C;` withs P as well
      w.getText().toLowerCase().matches(d.getQualifiedName().toLowerCase() + ".%")
      or
      not exists(Dependencies::withedUnit(w)) and
      w.getText().toLowerCase() = d.getQualifiedName().toLowerCase()
    ) and
    // a parent of a unit of the project is used by it
    not exists(Raw::CompilationUnit child |
      Dependencies::unitName(child).toLowerCase().matches(d.getQualifiedName().toLowerCase() + ".%")
    )
  }
}
