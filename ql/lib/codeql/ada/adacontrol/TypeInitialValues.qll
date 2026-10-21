/**
 * AdaControl rule `Type_Initial_Values`: each type has an initialization constant declared
 * with it, in the same declarative part, optionally named by a pattern
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module TypeInitialValues {
  /**
   * Holds if `t` is a type this rule checks: a type declaration (not a subtype, nor the
   * full view of a private type, which its partial view stands for, nor an incomplete or
   * formal type, nor a task or protected type).
   */
  predicate isChecked(Type t) {
    t instanceof Raw::TypeDecl and
    not t instanceof Raw::AnonymousTypeDecl and
    not t instanceof Raw::FormalTypeDecl and
    not t.getParent() instanceof Raw::GenericFormal and
    not exists(Type partial | TypeCategories::fullView(partial) = t)
  }

  /** Gets the declarative part `t` is declared in: a package's visible and private parts count as one. */
  private Raw::AdaNode region(Raw::BasicDecl d) {
    exists(Raw::DeclarativePart dp | d = dp.getDecls().getChild(_) |
      if dp instanceof Raw::PublicPart or dp instanceof Raw::PrivatePart
      then result = dp.getParent()
      else result = dp
    )
  }

  /** Holds if constant `c`, of type `t`, is declared in the same declarative part as `t`. */
  predicate initialConstant(Type t, Variable c) {
    isChecked(t) and
    c.isConstant() and
    TypeCategories::sameType(c.getType(), t) and
    region(c.getDeclaration()) = region(t)
  }

  /** Holds if `t` has no initialization constant whose name matches `pattern` (ignoring case). */
  bindingset[pattern]
  predicate lacksInitialValue(Type t, string pattern) {
    isChecked(t) and
    not exists(Variable c | initialConstant(t, c) and exists(c.getName().regexpFind("(?i)" + pattern, _, _)))
  }
}
