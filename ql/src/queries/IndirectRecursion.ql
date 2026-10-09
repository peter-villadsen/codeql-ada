/**
 * @name Indirect recursion
 * @description A subprogram that calls itself through other subprograms
 *              (P -> Q -> R -> P) uses unbounded stack space proportional to the
 *              recursion depth - a concern in embedded and safety-critical code where
 *              stack size is fixed and overflow is undetectable. A subprogram that calls
 *              itself directly is `ada/direct-recursion`. GNATcheck:
 *              `recursive_subprograms`.
 * @id ada/indirect-recursion
 * @kind problem
 * @problem.severity recommendation
 * @tags resources safety-critical
 */

import ada

/** Holds if `caller` contains a call to `callee`, a different subprogram. */
predicate callsOther(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee) and
  caller != callee
}

/** Holds if `caller` contains a call to `callee`. */
predicate calls(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee)
}

from Subprogram s, Subprogram next
where
  s.fromSource() and
  // `next` is the first subprogram on a cycle back to `s` through other subprograms;
  // if there are several, the one declared first
  next =
    min(Subprogram n |
      callsOther(s, n) and calls+(n, s)
    |
      n order by n.getLocation().getStartLine(), n.getLocation().getStartColumn()
    )
select s,
  "This subprogram is recursive through other subprograms: it calls $@, which leads back to it.",
  next, next.getName()
