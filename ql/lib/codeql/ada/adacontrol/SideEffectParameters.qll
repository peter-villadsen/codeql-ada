/**
 * AdaControl rule `Side_Effect_Parameters`: calls and generic instantiations whose
 * actual parameters call several functions with side effects, which interfere because
 * Ada does not define the order the actuals are evaluated in (`docs/adacontrol.md`).
 *
 * The functions are named with the data extension `sideEffectFunction(function,
 * group)`: functions of one group interfere with each other, and a function with
 * itself (AdaControl's functions given in one use of the rule). A call of an instance
 * of a generic function is a call of the generic, and renamings are followed. The
 * operands of an operator count as its actuals, since their order is not defined
 * either.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.adacontrol.Settings

module SideEffectParameters {
  /** Holds if `f` is a function with side effects of `group`. */
  predicate isSideEffectFunction(Subprogram f, string group) {
    exists(string name | sideEffectFunction(name, group) and f.hasQualifiedName(name))
  }

  /**
   * Gets an actual of `site`: an argument of a call, an operand of an operator, or an
   * actual of a generic instantiation.
   */
  Raw::AdaNode actual(Raw::AdaNode site) {
    result = site.(Call).getAnArgument()
    or
    result = [site.(Raw::BinOp).getLeft(), site.(Raw::BinOp).getRight()] and not site instanceof Call
    or
    result =
      site.(Raw::GenericInstantiation).getChild(_).(Raw::AssocList).getChild(_).(Raw::ParamAssoc).getRExpr()
  }

  /** Holds if `n` is in an actual of `site`. */
  private predicate inActual(Raw::AdaNode n, Raw::AdaNode site) { n.getParent*() = actual(site) }

  /** Holds if `c` is a call of a function with side effects of `group`, in an actual of `site`. */
  private predicate sideEffectIn(Call c, Raw::AdaNode site, string group) {
    isSideEffectFunction(c.getTarget(), group) and inActual(c, site)
  }

  /**
   * Holds if the actuals of `site` call `c1` and `c2`, two functions with side
   * effects of one group (`c1` before `c2`, neither in the other), and no call or
   * operator inside the actuals of `site` has both in its own actuals: `site` is the
   * innermost place whose evaluation order mixes them.
   */
  predicate interfering(Raw::AdaNode site, Call c1, Call c2) {
    exists(string group |
      sideEffectIn(c1, site, group) and
      sideEffectIn(c2, site, group) and
      c1 != c2 and
      not c1.getParent+() = c2 and
      not c2.getParent+() = c1 and
      (
        c1.getLocation().getStartLine() < c2.getLocation().getStartLine()
        or
        c1.getLocation().getStartLine() = c2.getLocation().getStartLine() and
        c1.getLocation().getStartColumn() < c2.getLocation().getStartColumn()
      ) and
      not exists(Raw::AdaNode inner |
        inActual(inner, site) and inActual(c1, inner) and inActual(c2, inner)
      )
    )
  }
}
