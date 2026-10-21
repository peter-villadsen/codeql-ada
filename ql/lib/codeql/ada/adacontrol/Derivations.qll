/**
 * AdaControl rule `Derivations`: derived types (from given parents, number of parents,
 * derivation depth) and the overriding indicators of primitive operations
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module Derivations {
  /** Gets the name of a parent of type `t`: the parent type of a derivation, or a progenitor. */
  Raw::Name aParentName(Type t) {
    exists(Raw::DerivedTypeDef d | d = t.getDefinition() |
      result = d.getSubtypeIndication().getName() or
      result = d.getInterfaces().getChild(_)
    )
    or
    result = t.getDefinition().(Raw::InterfaceTypeDef).getInterfaces().getChild(_)
  }

  /** Gets a parent of type `t` (`aParentName`), if it resolves. */
  Type aParent(Type t) { result = aParentName(t).getReferencedDecl() }

  /** Holds if `t` is a derived type: it has a parent or a progenitor. */
  predicate isDerived(Type t) { exists(aParentName(t)) }

  /** Gets the first named subtype of `t`: through subtype declarations to the type. */
  Type firstSubtype(Type t) {
    if t.isSubtype() and exists(t.getParentType())
    then result = firstSubtype(t.getParentType())
    else result = t
  }

  /**
   * `from`: `t` is derived, directly or not, from `ancestor` (a type, or a subtype of
   * it), or from a type declared in unit `ancestor`.
   */
  predicate derivesFrom(Type t, Raw::BasicDecl ancestor) {
    exists(Type p | p = aParent+(t) |
      ancestor = p or
      ancestor = firstSubtype(p) or
      ancestor = p.getEnclosingUnit().getBody().(Raw::LibraryItem).getItem()
    )
  }

  /**
   * `from` with a category: a parent of `t` belongs to `category`, derivations
   * traversed but not privacy.
   */
  bindingset[category]
  predicate derivesFromCategory(Type t, string category) {
    exists(Type p | p = aParent(t) |
      TypeCategories::declaredCategory(ultimateNoPrivacy(p)) = category
      or
      category = "tagged" and ultimateNoPrivacy(p).isTagged()
    )
  }

  /** Gets the type `t` ultimately derives from, through subtypes and derivations (not private views). */
  private Type ultimateNoPrivacy(Type t) {
    if exists(t.getParentType()) then result = ultimateNoPrivacy(t.getParentType()) else result = t
  }

  /** `max_parents`: the number of parents of `t`, the parent type and the progenitors. */
  int parentCount(Type t) { isDerived(t) and result = count(aParentName(t)) }

  /** Holds if a chain of `n` derivations leads from `t` up to some type. */
  private predicate chain(Type t, int n) {
    n = 0 and exists(t)
    or
    exists(Type p | p = aParent(t) and chain(p, n - 1)) and n <= 100
  }

  /** `max_depth`: the derivation depth of `t`, 0 for a type that is not derived. */
  int depth(Type t) { result = max(int n | chain(t, n)) }

  /** Gets the overriding indicator of subprogram declaration `d`, if it has one. */
  private Raw::OverridingNode indicator(Raw::BasicDecl d) {
    result = d.(Raw::ClassicSubpDecl).getOverriding() or
    result = d.(Raw::BaseSubpBody).getOverriding() or
    result = d.(Raw::SubpBodyStub).getOverriding()
  }

  /** Holds if `t` is tagged or an interface. */
  private predicate isTaggedOrInterface(Type t) {
    t.isTagged() or t.getDefinition() instanceof Raw::InterfaceTypeDef
  }

  /**
   * Holds if `s` is a primitive operation of tagged (or interface) type `t`, controlled
   * by its `i`th parameter: declared in the same package part as `t`, with that
   * parameter of type `t`.
   */
  private predicate primitiveOf(Subprogram s, Type t, int i) {
    isTaggedOrInterface(t) and
    s.getParameter(i).getType() = t and
    s.getParent().getParent().getParent() = t.getParent().getParent().getParent()
  }

  /** Holds if `s` is a primitive operation of a derived tagged type. */
  predicate isPrimitiveOfDerived(Subprogram s) {
    exists(Type t | primitiveOf(s, t, _) and isDerived(t))
  }

  /**
   * Holds if primitive `s` of a derived type overrides an operation inherited from its
   * parent or a progenitor, directly or not: a function or procedure like it, with the
   * same name and number of parameters, controlled by the same parameter.
   */
  predicate isOverriding(Subprogram s) {
    exists(Type t, Type ancestor, Subprogram inherited, int i |
      primitiveOf(s, t, i) and
      ancestor = aParent+(t) and
      primitiveOf(inherited, ancestor, i) and
      inherited.getName().toLowerCase() = s.getName().toLowerCase() and
      inherited.getNumberOfParameters() = s.getNumberOfParameters() and
      (if inherited.isFunction() then s.isFunction() else s.isProcedure())
    )
  }

  /**
   * `indicator`: declaration `d` of primitive `s` of a derived tagged type lacks the
   * indicator it needs, `expected` being `overriding` or `not overriding`. `d` is the
   * subprogram's first declaration (its spec, or the body acting as one) unless
   * `onBody`, which checks the body when there is a separate spec (AdaControl's
   * `body_required`).
   */
  predicate missingIndicator(Subprogram s, Raw::BasicDecl d, string expected, boolean onBody) {
    isPrimitiveOfDerived(s) and
    (
      onBody = false and d = s
      or
      onBody = true and d = s.getBody() and d != s
    ) and
    (
      isOverriding(s) and
      not indicator(d) instanceof Raw::OverridingOverriding and
      expected = "overriding"
      or
      not isOverriding(s) and
      not indicator(d) instanceof Raw::OverridingNotOverriding and
      expected = "not overriding"
    )
  }

  /** `body_forbidden`: body `d` of `s`, which has a separate spec, repeats an indicator. */
  predicate indicatorOnBody(Subprogram s, Raw::BasicDecl d) {
    isPrimitiveOfDerived(s) and
    d = s.getBody() and
    d != s and
    (
      indicator(d) instanceof Raw::OverridingOverriding or
      indicator(d) instanceof Raw::OverridingNotOverriding
    )
  }
}
