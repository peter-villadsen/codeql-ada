/**
 * @name Unchecked conversion as an actual parameter
 * @description An instance of `Unchecked_Conversion` called directly as the actual of a
 *              call gets around strong typing at the call. AdaControl rule
 *              `Actual_Parameters`, subrule `entity` (all calls, all formals,
 *              `Ada.Unchecked_Conversion`). The subrules `default_used`,
 *              `default_not_used` and `default_positional`, and other entities, are in
 *              `codeql.ada.adacontrol.ActualParameters` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/actual-parameters
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.ActualParameters

from Call call, DefiningName formal, Expr actual, BasicDecl uc
where
  uc.hasQualifiedName(["Ada.Unchecked_Conversion", "Unchecked_Conversion"]) and
  ActualParameters::entityActual(call, formal, actual, uc, false) and
  call.fromSource()
select actual,
  "The actual for " + ActualParameters::formalName(formal) +
    " is an unchecked conversion, which gets around strong typing."
