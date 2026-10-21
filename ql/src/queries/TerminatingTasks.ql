/**
 * @name Terminating task
 * @description A task whose body can complete, let an exception out, or accept a
 *              `terminate` alternative stops at some point; in a system whose tasks are
 *              meant to run forever (a server, a controller), the service it provides
 *              silently disappears. AdaControl rule `Terminating_Tasks`, decided along
 *              feasible control-flow paths rather than by the shape of the last
 *              statement. Exceptions that calls may raise are not counted, nor aborts.
 *              See `codeql.ada.adacontrol.TerminatingTasks` (`docs/adacontrol.md`).
 * @id ada/terminating-tasks
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags reliability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.TerminatingTasks

/** Gets why a task can terminate, in words. */
string reasonText(string reason) {
  reason = "completes" and result = "its statements can complete"
  or
  reason = "raises" and result = "an exception it raises can propagate out of it"
  or
  reason = "terminate" and result = "it has a terminate alternative"
}

from TaskBody t
where
  exists(string r | TerminatingTasks::isTerminating(t, r)) and
  t.fromSource()
select t,
  "Task " + t.getName().getName().getText() + " can terminate: " +
    concat(string r | TerminatingTasks::isTerminating(t, r) | reasonText(r), ", " order by r) + "."
