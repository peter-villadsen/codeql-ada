/**
 * @name Recursive subprogram
 * @description A subprogram that can call itself, directly or through other
 *              subprograms.
 * @kind problem
 * @id my-app/recursive
 * @problem.severity recommendation
 */

import ada

/** Holds if `caller` contains a call to `callee`. */
predicate calls(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee)
}

from Subprogram s, string how
where
  s.fromSource() and
  calls+(s, s) and
  if calls(s, s) then how = "directly" else how = "through other subprograms"
select s, "This subprogram calls itself " + how + "."
