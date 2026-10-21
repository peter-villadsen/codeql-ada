/**
 * @name Function returning an anonymous access type
 * @description A function whose result is of an anonymous access type (`return access T`)
 *              brings the accessibility rules of anonymous access types to every caller,
 *              which are hard to follow; return a named access type. AdaControl rule
 *              `Return_Type` with `anonymous_access`. The other kinds (class-wide,
 *              arrays, discriminated, task, protected) and given types are in
 *              `codeql.ada.adacontrol.ReturnType` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/return-type
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.ReturnType

from Subprogram f
where ReturnType::returnsKind(f, "anonymous_access") and f.fromSource()
select f, f.getName() + " returns an anonymous access type."
