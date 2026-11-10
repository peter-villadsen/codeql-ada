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
private import codeql.ada.adacontrol.Assignments
private import codeql.ada.adacontrol.SimplifiableStatements
private import codeql.ada.adacontrol.TypeCategories
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

  private predicate isAccessValue(Raw::Name n) {
    TypeCategories::category(n.getType(), true) = "access"
  }

  private predicate isArray(Raw::Name n) { TypeCategories::category(n.getType(), true) = "array" }

  /** Gets the defining name of the object that name `n` denotes as a whole: `X`, `Pkg.X`. */
  private Raw::DefiningName objectName(Raw::Name n) {
    result = Assignments::definingName(n)
    or
    exists(Raw::DottedName d | d = n |
      not d.getReferencedDecl() instanceof Raw::ComponentDecl and
      result = Assignments::definingName(d.getSuffix())
    )
  }

  /**
   * Holds if `n` is a part of the object `prefix` names: a component, an element or a
   * slice of it. Not through an access value: a part of `P.all` is one of `P.all`.
   */
  private predicate partOf(Raw::Name n, Raw::Name prefix) {
    exists(Raw::DottedName d | d = n |
      d.getReferencedDecl() instanceof Raw::ComponentDecl and
      prefix = d.getPrefix() and
      not isAccessValue(prefix)
    )
    or
    exists(Raw::CallExpr c | c = n |
      prefix = c.getName() and isArray(prefix) and not isAccessValue(prefix)
    )
  }

  /** Holds if `n` is the actual of an `in out` formal object, or the object it is a part of. */
  private predicate inVariableActual(Raw::Name n) {
    n = actualOfKind(_, _, "variable")
    or
    exists(Raw::Name part | inVariableActual(part) and partOf(part, n))
    or
    exists(Raw::ExplicitDeref d | inVariableActual(d) and n = d.getPrefix())
  }

  /** Holds if the indices of `c` and `d` are the same, as written. */
  private predicate sameIndices(Raw::CallExpr c, Raw::CallExpr d) {
    Assignments::isIndexing(c) and
    Assignments::isIndexing(d) and
    count(Assignments::index(c, _)) = count(Assignments::index(d, _)) and
    forall(int i | exists(Assignments::index(c, i)) |
      SimplifiableStatements::sameExpr(Assignments::index(c, i), Assignments::index(d, i))
    )
  }

  /** Holds if `c` is a slice, or has an index that is not static. */
  private predicate isDynamic(Raw::CallExpr c) {
    not Assignments::isIndexing(c)
    or
    exists(Raw::Expr i | i = Assignments::index(c, _) | not Assignments::isStaticIndex(i))
  }

  /**
   * Holds if names `a` and `b`, the actuals of `in out` formal objects or objects they
   * are parts of, may denote overlapping objects, with `strength` 3 (certain), 2
   * (possible) or 1 (unlikely).
   */
  private predicate overlap(Raw::Name a, Raw::Name b, int strength) {
    inVariableActual(a) and
    inVariableActual(b) and
    (
      objectName(a) = objectName(b) and strength = 3
      or
      // the same component of overlapping objects
      exists(Raw::DottedName d, Raw::DottedName e | d = a and e = b |
        d.getReferencedDecl() instanceof Raw::ComponentDecl and
        d.getReferencedDecl() = e.getReferencedDecl() and
        d.getSuffix().getText().toLowerCase() = e.getSuffix().getText().toLowerCase() and
        overlap(d.getPrefix(), e.getPrefix(), strength)
      )
      or
      // elements or slices of overlapping arrays
      exists(Raw::CallExpr c, Raw::CallExpr d, int s | c = a and d = b |
        partOf(c, c.getName()) and
        partOf(d, d.getName()) and
        overlap(c.getName(), d.getName(), s) and
        (
          sameIndices(c, d) and strength = s
          or
          not sameIndices(c, d) and
          (isDynamic(c) or isDynamic(d)) and
          strength = s.minimum(2)
        )
      )
      or
      // a part of an object that overlaps the other
      exists(Raw::Name p | partOf(a, p) and not partOf(b, _) | overlap(p, b, strength))
      or
      exists(Raw::Name p | partOf(b, p) and not partOf(a, _) | overlap(a, p, strength))
      or
      // dereferences
      exists(Raw::ExplicitDeref d, Raw::ExplicitDeref e | d = a and e = b |
        overlap(d.getPrefix(), e.getPrefix(), strength)
        or
        // any two access values of one type may designate the same object; the
        // strongest condition is kept (`aliasing`)
        d.getPrefix().getType() = e.getPrefix().getType() and
        strength = 1
      )
    )
  }

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
      kind = "variable" and
      exists(int s | s = max(int t | overlap(a, b, t)) |
        s = 3 and condition = "certain"
        or
        s = 2 and condition = "possible"
        or
        s = 1 and condition = "unlikely"
      )
      or
      exists(Raw::BasicDecl d, string attribute |
        d = entity(a, kind, attribute) and d = entity(b, kind, attribute)
      ) and
      condition = "certain"
    )
  }
}
