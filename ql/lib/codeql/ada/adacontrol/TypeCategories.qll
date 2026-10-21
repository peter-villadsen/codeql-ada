/**
 * AdaControl's type categories (user guide, appendix B), shared by the rules that take
 * a `<category>`: `()`, `access`, `array`, `delta`, `digits`, `extension`, `interface`,
 * `mod`, `new`, `private`, `protected`, `range`, `record`, `tagged`, `task`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations

module TypeCategories {
  /**
   * Holds if `t` is a partial view of a type: an incomplete declaration (`type T;`), a
   * private type (`type T is private;`) or a private extension (`... with private;`).
   */
  predicate isPartialView(Type t) {
    t instanceof Raw::IncompleteTypeDecl or
    t.isPrivate() or
    t.getDefinition().(Raw::DerivedTypeDef).getHasWithPrivate() instanceof Raw::WithPrivatePresent
  }

  /**
   * Gets the full declaration of partial view `t`: the type with the same qualified name
   * that is not a partial view. The extractor pairs bodies with their declarations, not
   * types with their completions, and a type cannot be overloaded, so the name decides.
   */
  Type fullView(Type t) {
    isPartialView(t) and
    result.getQualifiedName() = t.getQualifiedName() and
    not isPartialView(result)
  }

  /** Holds if `a` and `b` are views of the same type: equal, or partial and full view. */
  predicate sameType(Type a, Type b) {
    a = b or b = fullView(a) or a = fullView(b) or fullView(a) = fullView(b)
  }

  /**
   * Gets the type `t` ultimately is, through subtypes, derivations and private views
   * ("traverses derivations and privacy"): the first type up the chain with a definition
   * of its own.
   */
  Type ultimateType(Type t) {
    if exists(fullView(t))
    then result = ultimateType(fullView(t))
    else
      if exists(t.getParentType())
      then result = ultimateType(t.getParentType())
      else result = t
  }

  /**
   * Gets the category of type `t` as declared, without traversing anything: `new` for an
   * untagged derived type, `extension` for a tagged one, `private` for a private view.
   */
  string declaredCategory(Type t) {
    exists(Raw::TypeDef d | d = t.getDefinition() |
      d instanceof Raw::EnumTypeDef and result = "()"
      or
      d instanceof Raw::AccessDef and result = "access"
      or
      d instanceof Raw::ArrayTypeDef and result = "array"
      or
      (d instanceof Raw::OrdinaryFixedPointDef or d instanceof Raw::DecimalFixedPointDef) and
      result = "delta"
      or
      d instanceof Raw::FloatingPointDef and result = "digits"
      or
      d instanceof Raw::InterfaceTypeDef and result = "interface"
      or
      d instanceof Raw::ModIntTypeDef and result = "mod"
      or
      d instanceof Raw::SignedIntTypeDef and result = "range"
      or
      d instanceof Raw::RecordTypeDef and
      if t.isTagged() then result = "tagged" else result = "record"
      or
      d instanceof Raw::PrivateTypeDef and result = "private"
      or
      d instanceof Raw::DerivedTypeDef and
      if t.isTagged() then result = "extension" else result = "new"
    )
    or
    t instanceof Raw::ProtectedTypeDecl and result = "protected"
    or
    t instanceof Raw::TaskTypeDecl and result = "task"
  }

  /**
   * Gets the category of type `t`, traversing derivations and privacy: the category of
   * `ultimateType(t)`. A derived tagged type is `extension` when `separateExtension`
   * holds, else `tagged`. `private` remains only for a type whose full view is not known
   * (a generic formal private type, or one whose full view was not extracted).
   */
  bindingset[separateExtension]
  string category(Type t, boolean separateExtension) {
    exists(Type u, string c | u = ultimateType(t) and c = declaredCategory(u) |
      c = "extension" and separateExtension = false and result = "tagged"
      or
      not (c = "extension" and separateExtension = false) and result = c
    )
    or
    // a tagged type derived from one whose definition we cannot see
    exists(Type u | u = ultimateType(t) and not exists(declaredCategory(u)) and u.isTagged() |
      result = "tagged"
    )
  }
}
