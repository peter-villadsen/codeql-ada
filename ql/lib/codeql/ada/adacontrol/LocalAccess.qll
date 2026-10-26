/**
 * AdaControl rule `Local_Access`: `'Access`, `'Unchecked_Access` or `'Unrestricted_Access`
 * of an entity that is not global, that is not declared in (possibly nested) library
 * packages (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Places
private import codeql.ada.adacontrol.TypeCategories

module LocalAccess {
  /** Holds if `a` is `'Access`, `'Unchecked_Access` or `'Unrestricted_Access`. */
  predicate isAccessAttribute(Raw::AttributeRef a) {
    a.getAttribute().getValue().toLowerCase() =
      ["access", "unchecked_access", "unrestricted_access"]
  }

  /** Holds if `n` names an object of an access type, so that a component or element of it is a dereference. */
  private predicate isAccessValue(Raw::Name n) {
    TypeCategories::category(n.getType(), true) = "access"
  }

  /**
   * Gets the entity whose access value `prefix` takes: the object or subprogram it names,
   * through renamings; for a component or an element, the object it belongs to. A
   * component named alone (in a protected body) is the entity itself. No result through
   * a dereference (`P.all`, or a component of an access value), where the designated
   * object is not known.
   */
  Raw::BasicDecl entity(Raw::Name prefix) {
    result = prefix.(Raw::Identifier).getReferencedDecl().getUltimateDecl()
    or
    prefix instanceof Raw::DottedName and
    not prefix.getReferencedDecl() instanceof Raw::ComponentDecl and
    result = prefix.getReferencedDecl().getUltimateDecl()
    or
    // a component: `R.Field`
    exists(Raw::DottedName d | d = prefix |
      d.getReferencedDecl() instanceof Raw::ComponentDecl and
      not isAccessValue(d.getPrefix()) and
      result = entity(d.getPrefix())
    )
    or
    // an element or a slice: `A (I)`
    exists(Raw::CallExpr c | c = prefix |
      TypeCategories::category(c.getName().getType(), true) = "array" and
      not isAccessValue(c.getName()) and
      result = entity(c.getName())
    )
  }

  /** Holds if `e` is a subprogram declared in a protected type, a single protected object or a protected body. */
  private predicate isProtectedSubprogram(Raw::BasicDecl e) {
    e.getParent+() instanceof Raw::ProtectedDef or
    e.getParent+() instanceof Raw::ProtectedBody
  }

  /**
   * Gets the category of entity `e`, AdaControl's `<subrule>`: `constant`, `variable`,
   * `procedure`, `function`, `protected_procedure` or `protected_function`. A parameter
   * of mode `in` is a constant, one of mode `out` or `in out` a variable; a protected
   * component is a variable.
   */
  string category(Raw::BasicDecl e) {
    e instanceof Raw::ComponentDecl and result = "variable"
    or
    exists(Raw::ObjectDecl o | o = e |
      if o.getHasConstant() instanceof Raw::ConstantPresent
      then result = "constant"
      else result = "variable"
    )
    or
    exists(Raw::ParamSpec p | p = e |
      if p.getMode() instanceof Raw::ModeOut or p.getMode() instanceof Raw::ModeInOut
      then result = "variable"
      else result = "constant"
    )
    or
    exists(Raw::SubpSpec s, string kind |
      s = e.(Raw::ClassicSubpDecl).getSubpSpec() or s = e.(Raw::BaseSubpBody).getSubpSpec()
    |
      (
        s.getSubpKind() instanceof Raw::SubpKindProcedure and kind = "procedure"
        or
        s.getSubpKind() instanceof Raw::SubpKindFunction and kind = "function"
      ) and
      if isProtectedSubprogram(e) then result = "protected_" + kind else result = kind
    )
  }

  /**
   * Holds if `e` is global: declared at library level, in packages only. A parameter is
   * never global. The components and subprograms of a protected type count as global
   * when the type is, whatever the object.
   */
  predicate isGlobal(Raw::BasicDecl e) {
    Places::isLibraryLevel(e) and
    not e instanceof Raw::ParamSpec
  }

  /**
   * Holds if access attribute `a` takes the access value of `entity`, which is not
   * global and is of category `category`.
   */
  predicate localAccess(Raw::AttributeRef a, Raw::BasicDecl entity, string category) {
    isAccessAttribute(a) and
    entity = entity(a.getPrefix()) and
    not isGlobal(entity) and
    category = category(entity)
  }
}
