/**
 * @name Too many parameters
 * @description A subprogram or entry with more than 10 parameters is hard to call
 *              correctly; group them in a record. AdaControl rule `Parameter_Declarations`
 *              with `all_parameters, max 10`. The other subrules (parameters of each mode,
 *              defaulted, access, tagged, class-wide, `single_out_parameter`) and callable
 *              kinds are in `codeql.ada.adacontrol.ParameterDeclarations` for a query of
 *              your own (`docs/adacontrol.md`).
 * @id ada/parameter-declarations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.ParameterDeclarations

from BasicDecl c, int n
where n = ParameterDeclarations::parameterCount(c, "all_parameters") and n > 10 and c.fromSource()
select c, c.getAName() + " has " + n + " parameters, more than 10."
