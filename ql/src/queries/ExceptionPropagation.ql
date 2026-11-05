/**
 * @name Exception can propagate
 * @description An exception that escapes a task kills it silently; one that escapes a
 *              subprogram called from another language, or a call-back, unwinds through
 *              code that cannot handle it; and an exception declared locally that
 *              escapes its scope can only be handled by `when others`. Such a task or
 *              subprogram should end in a `when others` handler that does not raise
 *              again, and a local exception should be handled where it is declared.
 *              AdaControl rule `Exception_Propagation`, subrules `task`, `interface`
 *              (every convention), `local_exception`, and `parameter` for the call-back
 *              parameters set with the data extension `callbackParameter`, at level 0.
 *              The levels and the `declaration` subrule are in
 *              `codeql.ada.adacontrol.ExceptionPropagation` (`docs/adacontrol.md`).
 *              Files the GNAT binder generates (`b__*.adb`) are left out.
 * @id ada/exception-propagation
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.ExceptionPropagation
import codeql.ada.adacontrol.Settings
import codeql.ada.adacontrol.Generated

from AdaNode site, string msg, AdaNode other, string otherText
where
  site.fromSource() and
  not isBinderGenerated(site) and
  (
    exists(TaskBody t |
      ExceptionPropagation::canPropagate(t, 0) and
      site = t.getName() and
      msg =
        "Task $@ can let an exception out, and would then end silently: end its body with a when others handler that does not raise." and
      other = site and
      otherText = t.getName().getName().getText()
    )
    or
    exists(Subprogram s, string convention |
      ExceptionPropagation::isExported(s, convention) and
      ExceptionPropagation::canPropagate(s.getBody(), 0) and
      site = s.getBody() and
      msg =
        "$@ is exported with convention " + convention.toUpperCase() +
          " but can propagate an exception: end it with a when others handler that does not raise." and
      other = s and
      otherText = s.getName()
    )
    or
    exists(Call c, Parameter p, Subprogram s, string sub, string param |
      callbackParameter(sub, param) and
      p.getSubprogram().hasQualifiedName(sub) and
      p.hasName(param) and
      ExceptionPropagation::passesSubprogram(c, p, s) and
      ExceptionPropagation::canPropagate(s.getBody(), 0) and
      site = c.getArgumentFor(p) and
      msg = "$@ is registered as a call-back here but can propagate an exception." and
      other = s and
      otherText = s.getName()
    )
    or
    exists(DefiningName e, AdaNode b, string reason |
      ExceptionPropagation::localExceptionEscapes(e, b, site, reason) and
      other = e and
      otherText = e.getName().getText() and
      (
        reason = "unhandled" and
        msg = "Local exception $@ is not handled where it is declared, so it can escape its scope."
        or
        reason = "reraised" and
        msg = "This re-raises local exception $@ out of its scope."
        or
        reason = "raised" and msg = "This raises local exception $@ out of its scope."
      )
    )
  )
select site, msg, other, otherText
