/**
 * AdaControl rule `Instantiations`: instantiations of a generic, optionally only with
 * given actuals, with actuals already used by an earlier instantiation, or at given places
 * (`Places::isAt`) (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.ActualParameters
private import codeql.ada.adacontrol.TypeCategories

module Instantiations {
  /** Holds if `inst` instantiates `generic` (through generic renamings). */
  predicate instantiates(Raw::GenericInstantiation inst, Raw::BasicDecl generic) {
    inst.getDesignatedGeneric() = generic
  }

  /** Gets the actual `inst` gives for the generic's `i`th formal (0-based), by position or name. */
  Raw::Expr actual(Raw::GenericInstantiation inst, int i) {
    exists(Raw::DefiningName formal |
      ActualParameters::actualFor(inst, formal, result, _) and
      formal = ActualParameters::genericFormal(inst.getDesignatedGeneric(), i)
    )
  }

  /** Gets the declaration the `i`th actual of `inst` names, if it is a name that resolves. */
  Raw::BasicDecl actualEntity(Raw::GenericInstantiation inst, int i) {
    result = actual(inst, i).(Raw::Name).getReferencedDecl()
  }

  /**
   * Holds if the `i`th actual of `inst` is `entity`; or, with `subtypes`, a subtype of
   * type `entity` (AdaControl's `Type_Matches_Subtype`, on by default).
   */
  predicate actualIs(Raw::GenericInstantiation inst, int i, Raw::BasicDecl entity, boolean subtypes) {
    exists(Raw::BasicDecl a | a = actualEntity(inst, i) |
      a = entity and subtypes = [true, false]
      or
      a.(Type).isSubtype() and a.(Type).getParentType+() = entity and subtypes = true
    )
  }

  /** Holds if the `i`th actual of `inst` is a type of `category`, derivations and privacy not traversed. */
  bindingset[category]
  predicate actualIsOfCategory(Raw::GenericInstantiation inst, int i, string category) {
    TypeCategories::declaredCategory(actualEntity(inst, i)) = category
    or
    category = "tagged" and TypeCategories::declaredCategory(actualEntity(inst, i)) = "extension"
  }

  /** Gets a string identifying the `i`th actual of `inst`: the entity it names, or its text. */
  private string actualKey(Raw::GenericInstantiation inst, int i) {
    exists(Raw::Expr a | a = actual(inst, i) |
      result = a.(Raw::Name).getReferencedDecl().getQualifiedName()
      or
      not exists(a.(Raw::Name).getReferencedDecl().getQualifiedName()) and
      result = a.(Raw::Name).getText().toLowerCase()
    )
  }

  /** Gets a key for the actuals of `inst` at the positions in `positions` (`=`), in order. */
  private string actualsKey(Raw::GenericInstantiation inst, string positions) {
    positions = ["0", "1", "0,1", "0,1,2"] and
    result =
      strictconcat(int i, string k |
        i = positions.splitAt(",").toInt() and k = actualKey(inst, i)
      |
        k, "|" order by i
      ) and
    forall(int i | i = positions.splitAt(",").toInt() | exists(actualKey(inst, i)))
  }

  /** Gets a key ordering `inst` by file and position: earlier instantiations sort first. */
  private string position(Raw::GenericInstantiation inst) {
    exists(string path, int line, int col |
      inst.getLocation().hasLocationInfo(path, line, col, _, _) and
      result = path + ":" + line.toString().length() + ":" + line + ":" + col.toString().length() + ":" + col
    )
  }

  /**
   * `=`: `inst` instantiates the same generic as an earlier instantiation `previous`, with
   * the same actuals at `positions` (a comma-separated list of 0-based positions: `"0"`,
   * `"1"`, `"0,1"`, `"0,1,2"`). "Earlier" is by file name and position.
   */
  predicate repeats(Raw::GenericInstantiation inst, string positions, Raw::GenericInstantiation previous) {
    previous.getDesignatedGeneric() = inst.getDesignatedGeneric() and
    actualsKey(previous, positions) = actualsKey(inst, positions) and
    position(previous) < position(inst)
  }
}
