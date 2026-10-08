/**
 * @name Direct recursion
 * @description A subprogram that calls itself, directly or via its own forward
 *              declaration, uses unbounded stack space proportional to the recursion
 *              depth - a concern in embedded and safety-critical code where stack size is
 *              fixed and overflow is undetectable. GNATcheck: `recursive_subprograms`.
 * @id ada/direct-recursion
 * @kind problem
 * @problem.severity recommendation
 * @tags resources safety-critical
 */

import ada

from Call call
where
  // the caller is the innermost subprogram the call is written in, so a call from a
  // subprogram nested inside the target is not reported
  call.getTarget() = call.getCaller() and
  call.fromSource()
select call, "This call is a direct recursive call."
