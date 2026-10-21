/**
 * AdaControl rule `Max_Primitives`: types with too many primitive operations
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Declarations

module MaxPrimitives {
  /** Gets the package spec that declares `t` directly, in its visible or private part. */
  private Raw::BasePackageDecl packageOf(Type t) {
    t = result.getPublicPart().getDecls().getChild(_) or
    t = result.getPrivatePart().getDecls().getChild(_)
  }

  /**
   * Holds if `s` is a primitive operation of `t`: declared in the same package spec, with
   * a parameter or the result of type `t`; `visible` if declared in the visible part.
   */
  predicate isPrimitive(Subprogram s, Type t, boolean visible) {
    (s.getAParameter().getType() = t or s.getReturnType() = t) and
    exists(Raw::BasePackageDecl p | p = packageOf(t) |
      s = p.getPublicPart().getDecls().getChild(_) and visible = true
      or
      s = p.getPrivatePart().getDecls().getChild(_) and visible = false
    )
  }

  /** `visible`: the number of primitives of `t` declared in the visible part. */
  int visibleCount(Type t) {
    exists(packageOf(t)) and result = count(Subprogram s | isPrimitive(s, t, true))
  }

  /** `total`: the number of primitives of `t`, those in the private part included. */
  int totalCount(Type t) {
    exists(packageOf(t)) and result = count(Subprogram s | isPrimitive(s, t, _))
  }
}
