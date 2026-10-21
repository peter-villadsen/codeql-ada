/**
 * AdaControl rule `Aspects`: aspect specifications, all of them, given ones, or Boolean
 * ones whose value is left implicitly `True` (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module Aspects {
  /**
   * Gets the aspect mark of `a` as written, `Pre'Class` for a class-wide one: what
   * AdaControl's `<aspect mark>` matches, ignoring case.
   */
  string aspectMark(Raw::AspectAssoc a) {
    result = a.getId().(Raw::Name).getText()
    or
    exists(Raw::AttributeRef r | r = a.getId() |
      result = r.getPrefix().getText() + "'" + r.getAttribute().getValue()
    )
  }

  /** Holds if `a` specifies aspect `mark` (ignoring case). */
  bindingset[mark]
  predicate hasAspectMark(Raw::AspectAssoc a, string mark) {
    aspectMark(a).toLowerCase() = mark.toLowerCase()
  }

  /** `implicit_true`: `a` gives no value, so a Boolean aspect is `True` (`with Inline`). */
  predicate isImplicitTrue(Raw::AspectAssoc a) { not exists(a.getExpr()) }
}
