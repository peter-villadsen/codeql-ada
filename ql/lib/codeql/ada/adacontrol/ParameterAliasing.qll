/**
 * AdaControl rule `Parameter_Aliasing`: calls that pass the same variable, or
 * overlapping parts of one, for two parameters of which at least one is `out` or
 * `in out` (`docs/adacontrol.md`). The callee then updates one object through two
 * names, or reads through one what it writes through the other.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Overlaps
private import codeql.ada.adacontrol.TypeCategories

module ParameterAliasing {
  /**
   * Holds if `t` is passed by copy: an elementary type (scalar or access). An `in`
   * parameter of such a type is a copy, so `with_in` does not check it.
   */
  predicate isByCopy(Type t) {
    TypeCategories::category(t, true) = ["()", "range", "mod", "digits", "delta", "access"]
  }

  /**
   * Holds if `p` is a parameter the rule compares: `out` or `in out`, or, with
   * `withIn`, also `in` unless of a by-copy type.
   */
  bindingset[withIn]
  predicate isChecked(Parameter p, boolean withIn) {
    p.getMode() = ["out", "in out"]
    or
    withIn = true and p.getMode() = "in" and not isByCopy(p.getType())
  }

  /** Holds if `n` is an actual of a call, for a parameter that is not of a by-copy `in` mode. */
  private predicate isActual(Raw::Name n) {
    exists(Call c, Parameter p | n = c.getArgumentFor(p) and isChecked(p, true))
  }

  private module ActualOverlaps = Overlaps<isActual/1>;

  /**
   * Holds if call `c` passes, for parameters `p` and `q` (`p` before `q`), actuals
   * that overlap with `condition` (`certain`, `possible` or `unlikely`, the strongest
   * that applies), and at least one of them is `out` or `in out`. `withIn` is whether
   * one may be `in` (AdaControl's `with_in`).
   */
  predicate aliasing(Call c, Parameter p, Parameter q, string condition, boolean withIn) {
    p.getIndex() < q.getIndex() and
    withIn = [false, true] and
    isChecked(p, withIn) and
    isChecked(q, withIn) and
    (p.getMode() != "in" or q.getMode() != "in") and
    condition = ActualOverlaps::condition(c.getArgumentFor(p), c.getArgumentFor(q))
  }
}
