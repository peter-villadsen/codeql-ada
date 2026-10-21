/**
 * AdaControl rule `Not_Selected_Name`: given entities referred to by their simple name
 * rather than in selected notation (`Pkg.X`), except at given places
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Dependencies

module NotSelectedName {
  /**
   * Holds if identifier `id` refers to `entity` without a prefix: it is not the selector
   * of a dotted name, nor the name a declaration introduces, nor an `end` name, nor the
   * formal of a named association.
   */
  predicate simpleReference(Raw::Identifier id, Raw::BasicDecl entity) {
    id.getReferencedDecl() = entity and
    not id = any(Raw::DottedName d).getSuffix() and
    not id.getParent() instanceof Raw::DefiningName and
    not id.getParent*() instanceof Raw::EndName and
    // the formal named in a named association (`Object => X`) is not a use
    not id = any(Raw::ParamAssoc a).getDesignator() and
    not id = any(Raw::PragmaArgumentAssoc a).getName() and
    not id.getParent() = any(Raw::AggregateAssoc a).getDesignators() and
    not id.getParent() = any(Raw::CompositeConstraintAssoc a).getIds()
  }

  /** Gets the program unit `entity` is declared in: the innermost package, subprogram, task or protected unit. */
  private Raw::AdaNode programUnit(Raw::BasicDecl entity) {
    result = entity.getParent+() and
    isProgramUnit(result) and
    not exists(Raw::AdaNode inner |
      inner = entity.getParent+() and isProgramUnit(inner) and inner.getParent+() = result
    )
  }

  private predicate isProgramUnit(Raw::AdaNode n) {
    n instanceof Raw::GenericDecl or
    n instanceof Raw::BasePackageDecl or
    n instanceof Raw::PackageBody or
    n instanceof Raw::BaseSubpBody or
    n instanceof Raw::TaskBody or
    n instanceof Raw::TaskTypeDecl or
    n instanceof Raw::ProtectedTypeDecl or
    n instanceof Raw::SingleProtectedDecl or
    n instanceof Raw::ProtectedBody
  }

  /** Holds if `n` is in the program unit declaring `entity`, its spec or its body. */
  private predicate inDeclaringUnit(Raw::AdaNode n, Raw::BasicDecl entity) {
    exists(Raw::AdaNode u | u = programUnit(entity) |
      n.getParent+() = u or
      exists(Raw::BasicDecl body | ada_body_part(u, body) and n.getParent+() = body)
    )
  }

  /** Gets the full name of the library unit of compilation unit `cu`, lower-cased. */
  private string unitName(Raw::CompilationUnit cu) { result = Dependencies::unitName(cu).toLowerCase() }

  /**
   * Holds if the simple reference `id` to `entity` is allowed at `place`, AdaControl's
   * exception places: `none` (never), `unit` (in the program unit declaring it),
   * `compilation` (in its compilation unit, or the body of that unit), `family` (also in
   * the child units of that unit).
   */
  bindingset[place]
  predicate allowedAt(Raw::Identifier id, Raw::BasicDecl entity, string place) {
    place = "unit" and inDeclaringUnit(id, entity)
    or
    place = ["compilation", "family"] and
    unitName(id.getEnclosingUnit()) = unitName(entity.getEnclosingUnit())
    or
    place = "family" and
    unitName(id.getEnclosingUnit()).matches(unitName(entity.getEnclosingUnit()) + ".%")
  }

  /** `Not_Selected_Name`: `id` refers to `entity` by its simple name, where `place` does not allow it. */
  bindingset[place]
  predicate notSelected(Raw::Identifier id, Raw::BasicDecl entity, string place) {
    simpleReference(id, entity) and not allowedAt(id, entity, place)
  }
}
