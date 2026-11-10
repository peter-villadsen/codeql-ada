/**
 * @name Actuals call interfering functions
 * @description Ada does not define the order in which the actual parameters of a call
 *              are evaluated. When two of them call functions with side effects that
 *              interfere, the result depends on the compiler. AdaControl rule
 *              `Side_Effect_Parameters`, for the functions named with the data extension
 *              `sideEffectFunction` (by group: a group's functions interfere with each
 *              other and with themselves): calls, operators and generic
 *              instantiations whose actuals call two of them. With no row, nothing is
 *              reported. Left out, as in AdaControl: defaulted parameters; and a
 *              parameterless function named alone as a generic actual, which may be
 *              the actual of a formal subprogram rather than a call. See
 *              `codeql.ada.adacontrol.SideEffectParameters` (`docs/adacontrol.md`).
 * @id ada/side-effect-parameters
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.SideEffectParameters

from AdaNode site, Call c1, Call c2
where
  site.fromSource() and
  SideEffectParameters::interfering(site, c1, c2)
select site,
  "The order of the $@ and the $@ in the actuals of this " +
    any(string k |
      if site instanceof Raw::GenericInstantiation then k = "instantiation"
      else
        if site instanceof Call then k = "call"
        else k = "operator"
    ) + " is not defined, and both have side effects.", c1, "call of " + c1.getTarget().getName(),
  c2, "call of " + c2.getTarget().getName()
