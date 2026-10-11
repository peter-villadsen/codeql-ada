/**
 * @name Subprogram calls itself
 * @description A call from a subprogram to itself: direct recursion.
 * @kind problem
 * @id my-app/calls-itself
 * @problem.severity recommendation
 */

import ada

from Call c, Subprogram s
where
  c.fromSource() and
  s = c.getCaller() and
  c.getTarget() = s
select c, "This call is to $@, the subprogram it is in.", s, s.getName()
