/**
 * AdaControl rule `Actual_Parameters`: properties of the actuals of calls and generic
 * instantiations (`docs/adacontrol.md`).
 *
 * A *site* is a call (`Call`) or a generic instantiation. A *formal* is the defining
 * name of one of its target's parameters: a `Parameter` of the called subprogram, or a
 * generic formal object or subprogram of the instantiated generic. Each subrule is a
 * predicate; a query chooses the sites, formals and entities to check.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Calls

module ActualParameters {
  /** Gets the `i`th name (0-based) declared by the formal part of generic `g`. */
  private Raw::DefiningName genericFormal(Raw::GenericDecl g, int i) {
    result =
      rank[i + 1](Raw::DefiningName dn, Raw::GenericFormal f, int j |
        f = g.getFormalPart().getDecls().getChild(j) and
        dn = f.getDecl().getADefiningName()
      |
        dn order by j, dn.getParentIndex()
      )
  }

  /** Gets the generic formal `f` declares the name `dn` of. */
  private Raw::BasicDecl formalDecl(Raw::DefiningName dn) {
    dn = genericFormal(_, _) and result.getADefiningName() = dn
  }

  /** Gets the actual list of instantiation `inst`. */
  private Raw::AssocList instParams(Raw::GenericInstantiation inst) {
    result = inst.(Raw::GenericPackageInstantiation).getParams() or
    result = inst.(Raw::GenericSubpInstantiation).getParams()
  }

  /** Holds if `site` is a call or an instantiation, and `formal` one of its target's formals. */
  predicate formalOf(Raw::AdaNode site, Raw::DefiningName formal) {
    formal = site.(Call).getTarget().getAParameter()
    or
    formal = genericFormal(site.(Raw::GenericInstantiation).getDesignatedGeneric(), _)
  }

  /** Gets the name of `formal`, as written. */
  string formalName(Raw::DefiningName formal) { result = formal.getName().getText() }

  /** Gets the default of `formal`: `:= ...` of a parameter or formal object, `is ...` of a formal subprogram. */
  Raw::Expr defaultOf(Raw::DefiningName formal) {
    result = formal.(Parameter).getDefaultExpr()
    or
    result = formalDecl(formal).(Raw::ObjectDecl).getDefaultExpr()
    or
    result = formalDecl(formal).(Raw::FormalSubpDecl).getDefaultExpr()
  }

  /** Holds if `formal` has a default. */
  predicate hasDefault(Raw::DefiningName formal) { exists(defaultOf(formal)) }

  /**
   * Holds if `site` gives `actual` for `formal`; `positional` says whether without a
   * name (`F (1)` rather than `F (X => 1)`). The prefix of a prefixed-view call
   * (`Obj.Op`) is positional.
   */
  predicate actualFor(Raw::AdaNode site, Raw::DefiningName formal, Raw::Expr actual, boolean positional) {
    exists(Call c | c = site |
      actual = c.getArgumentFor(formal) and
      if exists(actual.getParent().(Raw::ParamAssoc).getDesignator())
      then positional = false
      else positional = true
    )
    or
    exists(Raw::GenericInstantiation inst, Raw::ParamAssoc a, Raw::GenericDecl g |
      inst = site and
      g = inst.getDesignatedGeneric() and
      a = instParams(inst).getChild(_) and
      actual = a.getRExpr()
    |
      not exists(a.getDesignator()) and
      formal = genericFormal(g, a.getParentIndex()) and
      positional = true
      or
      formal = genericFormal(g, _) and
      formalName(formal).toLowerCase() = a.getDesignator().(Raw::Name).getText().toLowerCase() and
      positional = false
    )
  }

  /** `default_used`: `site` leaves defaulted `formal` to its default. */
  predicate defaultUsed(Raw::AdaNode site, Raw::DefiningName formal) {
    formalOf(site, formal) and
    hasDefault(formal) and
    not actualFor(site, formal, _, _)
  }

  /** `default_not_used`: `site` gives `actual` for defaulted `formal`. */
  predicate defaultNotUsed(Raw::AdaNode site, Raw::DefiningName formal, Raw::Expr actual) {
    hasDefault(formal) and actualFor(site, formal, actual, _)
  }

  /** `default_positional`: `site` gives `actual` for defaulted `formal`, positionally. */
  predicate defaultPositional(Raw::AdaNode site, Raw::DefiningName formal, Raw::Expr actual) {
    hasDefault(formal) and actualFor(site, formal, actual, true)
  }

  /** Gets `e` without parentheses, type conversions and qualification around it. */
  private Raw::Expr strip(Raw::Expr e) {
    result = strip(e.(Raw::ParenExpr).getExpr())
    or
    result = strip(e.(Raw::QualExpr).getSuffix())
    or
    // a type conversion is a `CallExpr` naming a type, with one argument
    exists(Raw::CallExpr conv | conv = e and conv.getName().getReferencedDecl() instanceof Raw::BaseTypeDecl |
      result = strip(conv.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr())
    )
    or
    not e instanceof Raw::ParenExpr and
    not e instanceof Raw::QualExpr and
    not e.(Raw::CallExpr).getName().getReferencedDecl() instanceof Raw::BaseTypeDecl and
    result = e
  }

  /**
   * Holds if expression `e` denotes `entity`: names it (through renamings), calls it,
   * or calls an instance of it when it is a generic.
   */
  private predicate denotes(Raw::Expr e, Raw::BasicDecl entity) {
    exists(Raw::Name n | n = e | n.getReferencedDecl().getUltimateDecl() = entity)
    or
    // a call to an instance of a generic subprogram targets the generic
    e.(Call).getTarget() = entity
    or
    exists(Raw::GenericSubpInstantiation inst |
      inst.getDesignatedGeneric() = entity and
      e.(Raw::CallExpr).getName().getReferencedDecl() = inst
    )
  }

  /**
   * `entity`: `site` gives `actual` for `formal`, and `actual` is `entity` (a name of it,
   * a call to it, or a call to an instance of it), possibly in parentheses, converted or
   * qualified; with `anywhere`, `entity` appears anywhere in `actual`.
   */
  predicate entityActual(
    Raw::AdaNode site, Raw::DefiningName formal, Raw::Expr actual, Raw::BasicDecl entity,
    boolean anywhere
  ) {
    actualFor(site, formal, actual, _) and
    (
      denotes(strip(actual), entity) and anywhere = false
      or
      exists(Raw::Expr part | part.getParent*() = actual and denotes(part, entity)) and
      anywhere = true
    )
  }
}
