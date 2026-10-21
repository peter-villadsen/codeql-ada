/**
 * AdaControl rule `Entities`: any use of given entities, optionally only at given places
 * (`Places::useIsAt`) (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module Entities {
  /**
   * Holds if `n` is a use of a name: not the name a declaration introduces, nor an `end`
   * name, nor the selector of a dotted name (the dotted name is the use), nor a call (its
   * name is the use).
   */
  private predicate isUse(Raw::Name n) {
    not n instanceof Raw::CallExpr and
    not n.getParent() instanceof Raw::DefiningName and
    not n.getParent*() instanceof Raw::EndName and
    not n = any(Raw::DottedName d).getSuffix()
  }

  /** Gets the declaration name `n` denotes, before renamings are followed. */
  private Raw::BasicDecl named(Raw::Name n) {
    result = n.getReferencedDecl()
    or
    result = n.(Raw::DottedName).getSuffix().getReferencedDecl() and
    not exists(n.getReferencedDecl())
  }

  /**
   * Holds if name `n` uses `entity`, by its own name or a renaming of it ("reports on the
   * use of the entity, not the name"). With `instanceOnly`, only through an instance of
   * generic `entity` (AdaControl's `instance`); without it, the generic's own uses too.
   */
  predicate uses(Raw::Name n, Raw::BasicDecl entity, boolean instanceOnly) {
    isUse(n) and
    exists(Raw::BasicDecl d | d = named(n) |
      (d = entity or d.getUltimateDecl() = entity) and instanceOnly = false
      or
      d.(Raw::GenericInstantiation).getDesignatedGeneric() = entity and
      instanceOnly = [true, false]
    )
  }

  /** Holds if `a` uses attribute `name` (AdaControl's `all 'Unchecked_Access`), ignoring case. */
  bindingset[name]
  predicate usesAttribute(Raw::AttributeRef a, string name) {
    a.getAttribute().getValue().toLowerCase() = name.toLowerCase()
  }
}
