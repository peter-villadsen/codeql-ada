/**
 * @name Overriding operation without indicator
 * @description A primitive operation of a derived tagged type that overrides an
 *              inherited one says so with `overriding`; without the indicator, a typo in
 *              its name or profile silently declares a new operation instead, and calls
 *              keep dispatching to the inherited one. AdaControl rule `Derivations`,
 *              subrule `indicator` with `overriding`, `tagged` and `declaration`. The
 *              subrules `from`, `max_parents` and `max_depth`, `not overriding`
 *              indicators and indicators on bodies are in
 *              `codeql.ada.adacontrol.Derivations` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/derivations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.Derivations

from Subprogram s, BasicDecl d
where
  Derivations::missingIndicator(s, d, "overriding", false) and
  d.fromSource()
select d, s.getName() + " overrides an inherited operation, but is not declared overriding."
