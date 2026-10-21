/**
 * @name Pragma applying to several overloaded entities
 * @description A pragma whose argument names an overloaded subprogram (`pragma Inline
 *              (Put)` with several `Put`s declared together) applies to all of them, which
 *              is easily more than meant. AdaControl rule `Pragmas` with `multiple all`.
 *              Given pragmas, `all` and `nonstandard` are in
 *              `codeql.ada.adacontrol.Pragmas` for a query of your own
 *              (`docs/adacontrol.md`); `ada/pragma-suppress`, `ada/warnings-off` and
 *              `ada/spark-mode-off` are three fixed pragmas.
 * @id ada/pragmas
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Pragmas

from PragmaNode p
where Pragmas::isMultiple(p) and p.fromSource()
select p, "pragma " + p.getId().getValue() + " applies to several overloaded entities."
