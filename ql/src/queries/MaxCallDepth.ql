/**
 * @name Call chain too deep
 * @description A call that stacks more frames than the coding standard allows may
 *              overflow a small task stack. AdaControl rule `Max_Call_Depth`, with the
 *              limit of the data extension `maxCallDepth` (default 15): a call of a
 *              subprogram whose deepest chain of calls is longer. A chain that reaches
 *              a subprogram without a body (imported, or from the Ada library) gives a
 *              minimum depth. Calls of recursive subprograms, whose depth is not
 *              finite, are left to `ada/direct-recursion` and `ada/indirect-recursion`;
 *              they are in `codeql.ada.adacontrol.MaxCallDepth` (`docs/adacontrol.md`).
 * @id ada/max-call-depth
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.MaxCallDepth
import codeql.ada.adacontrol.Settings

/** Gets the depth limit: the smallest row of `maxCallDepth`, else 15. */
int limit() {
  result = min(int l | maxCallDepth(l))
  or
  not maxCallDepth(_) and result = 15
}

from Call c, Subprogram target, int depth
where
  c.fromSource() and
  target = c.getTarget() and
  not MaxCallDepth::isRecursive(target) and
  depth = MaxCallDepth::callDepth(c) and
  depth > limit()
select c,
  "This call of $@ has a depth of " +
    any(string s | if MaxCallDepth::isExactCall(c) then s = "" else s = "at least ") + depth +
    " (limit " + limit() + ").", target, target.getName()
