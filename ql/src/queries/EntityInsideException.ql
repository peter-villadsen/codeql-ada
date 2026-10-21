/**
 * @name Entry call in an exception handler
 * @description An entry call can block; in an exception handler it can hold up the
 *              recovery, or deadlock if the exception came from the task or protected
 *              object called. AdaControl rule `Entity_Inside_Exception` with
 *              `entry_calls`. References to given entities, and all calls, are in
 *              `codeql.ada.adacontrol.EntityInsideException` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/entity-inside-exception
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.EntityInsideException

from CallStmt call
where EntityInsideException::entryCallIn(call, _) and call.fromSource()
select call, "Entry call in an exception handler: it may block the handling of the exception."
