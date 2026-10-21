/**
 * @name Boolean aspect without a value
 * @description A Boolean aspect given without `=> True` (`with Inline`) is `True` only
 *              implicitly; a coding standard that asks for explicit values wants
 *              `with Inline => True`. AdaControl rule `Aspects`, `implicit_true`.
 *              Reporting all aspects, or given aspect marks, is in
 *              `codeql.ada.adacontrol.Aspects` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/aspects
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Aspects

from AspectAssoc a
where Aspects::isImplicitTrue(a) and a.fromSource()
select a, "Aspect " + Aspects::aspectMark(a) + " is True only implicitly: write => True."
