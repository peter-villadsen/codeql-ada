/**
 * AdaControl rule `Return_Type`: functions returning given types or kinds of types
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module ReturnType {
  /** Holds if `t` is limited: `limited` in its definition, an interface that is, a task or protected type. */
  private predicate isLimited(Type t) {
    exists(Type u | u = TypeCategories::ultimateType(t) |
      u.getDefinition().(Raw::RecordTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::PrivateTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::DerivedTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::InterfaceTypeDef).getInterfaceKind() instanceof Raw::InterfaceKindLimited or
      u instanceof Raw::TaskTypeDecl or
      u instanceof Raw::ProtectedTypeDecl
    )
  }

  /** Holds if `t` is, or has a component (at any depth) of, a type satisfying the kind `k` (`task`, `protected`). */
  private predicate contains(Type t, string k) {
    exists(Type u | u = TypeCategories::ultimateType(t) |
      k = "task" and u instanceof Raw::TaskTypeDecl
      or
      k = "protected" and u instanceof Raw::ProtectedTypeDecl
      or
      contains(u.getAComponent().getType(), k)
      or
      contains(namedType(u.getDefinition().(Raw::ArrayTypeDef).getComponentType().getTypeExpr()), k)
    )
  }

  /**
   * Holds if function `f` returns a type of kind `kind`: `anonymous_access`, `class_wide`,
   * `limited_class_wide`, `constrained_array`, `unconstrained_array`,
   * `unconstrained_discriminated`, `task`, `protected`.
   */
  predicate returnsKind(Subprogram f, string kind) {
    f.isFunction() and
    exists(Raw::TypeExpr te | te = f.getReturnTypeExpr() |
      te.(Raw::AnonymousType).getTypeDecl().getTypeDef() instanceof Raw::AccessDef and
      kind = "anonymous_access"
      or
      exists(Raw::AttributeRef cw, Type t |
        cw = te.(Raw::SubtypeIndication).getName() and
        cw.getAttribute().getValue().toLowerCase() = "class" and
        t = cw.getPrefix().getReferencedDecl()
      |
        kind = "class_wide"
        or
        isLimited(t) and kind = "limited_class_wide"
      )
      or
      exists(Type t, Type u |
        t = f.getReturnType() and
        u = TypeCategories::ultimateType(t) and
        not exists(te.(Raw::SubtypeIndication).getConstraint())
      |
        u.getDefinition().(Raw::ArrayTypeDef).getIndices() instanceof Raw::ConstrainedArrayIndices and
        kind = "constrained_array"
        or
        u.getDefinition().(Raw::ArrayTypeDef).getIndices() instanceof Raw::UnconstrainedArrayIndices and
        not exists(t.(Raw::SubtypeDecl).getSubtype().getConstraint()) and
        kind = "unconstrained_array"
        or
        exists(u.(Raw::TypeDecl).getDiscriminants().(Raw::KnownDiscriminantPart)) and
        not exists(t.(Raw::SubtypeDecl).getSubtype().getConstraint()) and
        kind = "unconstrained_discriminated"
        or
        contains(t, kind) and kind = ["task", "protected"]
      )
    )
  }

  /** `type`: function `f` returns `t`, or a subtype of it (`exact` if `t` itself). */
  predicate returnsType(Subprogram f, Type t, boolean exact) {
    f.getReturnType() = t and exact = true
    or
    f.getReturnType() != t and
    f.getReturnType().isSubtype() and
    f.getReturnType().getParentType+() = t and
    exact = false
  }
}
