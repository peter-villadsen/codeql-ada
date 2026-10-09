/**
 * @name Recursive subprogram
 * @description A subprogram that can call itself, directly or through other
 *              subprograms (P -> Q -> R -> P). Recursion uses stack space that grows
 *              with its depth, a concern where the stack size is fixed.
 * @kind problem
 * @id my-app/recursive-subprogram
 * @problem.severity recommendation
 */

import ada

/** Holds if `caller` contains a call to `callee`. */
predicate calls(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee)
}

from Subprogram s, Subprogram next
where
  s.fromSource() and
  // `next` is the first subprogram on a cycle back to `s` (`s` itself if it calls
  // itself directly); if there are several, the one declared first
  next =
    min(Subprogram n |
      calls(s, n) and calls*(n, s)
    |
      n order by n.getLocation().getStartLine(), n.getLocation().getStartColumn()
    )
select s, "This subprogram is recursive: it calls $@, which leads back to it.", next, next.getName()
