/**
 * @name Duplicate initialization call
 * @description Calling an initialization procedure twice with the same values, or for
 *              the same object, initializes it again and loses what was done in
 *              between. AdaControl rule `Duplicate_Initialization_Calls`, for the
 *              procedures named with the data extension `initializationProcedure`, or,
 *              without one, the procedures named `Init` or `Initialize` with only `in`
 *              parameters. For named procedures, calls for the same `out` object,
 *              calls with a value that is not static, and procedures whose parameters
 *              fit neither pattern, are reported too. See
 *              `codeql.ada.adacontrol.DuplicateInitializationCalls` (`docs/adacontrol.md`).
 * @id ada/duplicate-initialization-calls
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.DuplicateInitializationCalls

from AdaNode site, string msg, AdaNode other, string otherText
where
  site.fromSource() and
  (
    exists(Call first, Subprogram s |
      DuplicateInitializationCalls::duplicate(first, site) and
      s = first.getTarget() and
      exists(boolean configured |
        DuplicateInitializationCalls::isInitializationProcedure(s, configured)
      |
        // without a setting, a procedure named Init may well be meant to initialize
        // an object again (a context reused after it is finalized)
        DuplicateInitializationCalls::pattern(s) = "in" or configured = true
      ) and
      other = first and
      otherText = "an earlier call" and
      if DuplicateInitializationCalls::pattern(s) = "in"
      then msg = "This call of " + s.getName() + " passes the same values as $@."
      else msg = "This call of " + s.getName() + " initializes the same object as $@."
    )
    or
    exists(Subprogram s, Parameter p |
      DuplicateInitializationCalls::isInitializationProcedure(s, true) and
      DuplicateInitializationCalls::pattern(s) = "in" and
      DuplicateInitializationCalls::nonStaticActual(site, p) and
      site.(Call).getTarget() = s and
      msg = "This call of initialization procedure " + s.getName() + " passes a value for $@ that is not static." and
      other = p and
      otherText = p.getName()
    )
    or
    exists(Subprogram s |
      DuplicateInitializationCalls::isInitializationProcedure(s, true) and
      not exists(DuplicateInitializationCalls::pattern(s)) and
      site = s and
      msg =
        "Initialization procedure $@ has neither only in parameters nor exactly one out parameter and no in out one." and
      other = s and
      otherText = s.getName()
    )
  )
select site, msg, other, otherText
