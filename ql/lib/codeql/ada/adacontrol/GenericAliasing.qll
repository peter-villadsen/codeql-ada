/**
 * AdaControl rule `Generic_Aliasing`: instantiations that give the same entity, or
 * entities that may overlap, for two formals of the generic (`docs/adacontrol.md`).
 *
 * The formals compared are those of one kind (`formalKind`): `in out` formal objects
 * (`variable`), formal types (`type`), formal subprograms (`subprogram`) and formal
 * packages (`package`). An `in` formal object is a copy and never aliases. How sure
 * the aliasing is, AdaControl's condition, is `certain`, `possible` (variables only: an
 * element at an index that is not static, or a slice) or `unlikely` (variables only:
 * two dereferences `.all` of access values of the same type).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.adacontrol.ActualParameters
private import codeql.ada.adacontrol.Instantiations
private import codeql.ada.adacontrol.Overlaps
private import codeql.ada.internal.CallResolution as CallResolution

module GenericAliasing {
  /**
   * Gets the kind of generic formal `formal`, as AdaControl names it: `variable` for
   * an `in out` formal object, `type`, `subprogram` or `package`; `object` for an `in`
   * formal object, which the rule does not check.
   */
  string formalKind(Raw::DefiningName formal) {
    exists(Raw::GenericFormal f | formal = f.getDecl().getADefiningName() |
      f instanceof Raw::GenericFormalObjDecl and
      (
        if f.getDecl().(Raw::ObjectDecl).getMode() instanceof Raw::ModeInOut
        then result = "variable"
        else result = "object"
      )
      or
      f instanceof Raw::GenericFormalTypeDecl and result = "type"
      or
      f instanceof Raw::GenericFormalSubpDecl and result = "subprogram"
      or
      f instanceof Raw::GenericFormalPackage and result = "package"
    )
  }

  /** Gets the `i`th formal (0-based) of the generic `inst` instantiates. */
  Raw::DefiningName formal(Raw::GenericInstantiation inst, int i) {
    result = ActualParameters::genericFormal(inst.getDesignatedGeneric(), i)
  }

  /** Gets the actual `inst` gives for its `i`th formal, if that formal is of `kind`. */
  private Raw::Expr actualOfKind(Raw::GenericInstantiation inst, int i, string kind) {
    result = Instantiations::actual(inst, i) and
    kind = formalKind(formal(inst, i)) and
    kind != "object"
  }

  /* --- variables ------------------------------------------------------------- */

  /** Holds if `n` is the actual of an `in out` formal object. */
  private predicate isVariableActual(Raw::Name n) { n = actualOfKind(_, _, "variable") }

  private module VariableOverlaps = Overlaps<isVariableActual/1>;

  /* --- types, subprograms, packages ------------------------------------------- */

  /** Gets the package declaration `d` is, through package renamings. */
  private Raw::BasicDecl resolvePackage(Raw::BasicDecl d) {
    not d instanceof Raw::PackageRenamingDecl and result = d
    or
    result =
      resolvePackage(d.(Raw::PackageRenamingDecl).getRenames().getRenamedObject().getReferencedDecl())
  }

  /** Gets the declaration `d` designates as a subprogram: after renamings, the `Subprogram`. */
  private Raw::BasicDecl resolveSubprogram(Raw::BasicDecl d) {
    exists(Raw::BasicDecl s |
      s = CallResolution::resolveSubpRenaming(d)
      or
      not exists(CallResolution::resolveSubpRenaming(d)) and s = d
    |
      result.(Subprogram).getADeclaration() = s
      or
      not exists(Subprogram p | p.getADeclaration() = s) and result = s
    )
  }

  /**
   * Gets the entity actual `e` of `kind` names, and in `attribute` the attribute
   * applied to it (`class` for `T'Class`), or `""`: the declaration, after renamings
   * for a subprogram or a package. A subprogram must be in the source: GNAT's
   * predefined operators (`"+"`) of different types are not told apart.
   */
  Raw::BasicDecl entity(Raw::Expr e, string kind, string attribute) {
    exists(Raw::BasicDecl d |
      d = e.(Raw::Name).getReferencedDecl() and not e instanceof Raw::AttributeRef and attribute = ""
    |
      kind = "type" and result = d
      or
      kind = "subprogram" and result = resolveSubprogram(d) and result.fromSource()
      or
      kind = "package" and result = resolvePackage(d)
    )
    or
    kind = "type" and
    exists(Raw::AttributeRef a | a = e |
      result = a.getPrefix().getReferencedDecl() and
      attribute = a.getAttribute().getText().toLowerCase()
    )
  }

  /**
   * Holds if instantiation `inst` gives, for its formals `i` and `j` (`i < j`) of kind
   * `kind` (`variable`, `type`, `subprogram`, `package`), actuals that alias with
   * condition `condition` (`certain`, `possible`, `unlikely`): the strongest that
   * applies.
   */
  predicate aliasing(Raw::GenericInstantiation inst, int i, int j, string kind, string condition) {
    i < j and
    exists(Raw::Expr a, Raw::Expr b |
      a = actualOfKind(inst, i, kind) and b = actualOfKind(inst, j, kind)
    |
      kind = "variable" and condition = VariableOverlaps::condition(a, b)
      or
      exists(Raw::BasicDecl d, string attribute |
        d = entity(a, kind, attribute) and d = entity(b, kind, attribute)
      ) and
      condition = "certain"
    )
  }
}
