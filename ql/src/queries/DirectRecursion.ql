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

/**
 * Gets the innermost `BaseSubpBody` enclosing `n`, i.e. the subprogram `n` textually
 * belongs to, ignoring any subprogram nested more deeply between them.
 */
private Raw::BaseSubpBody getInnermostEnclosingSubprogram(Raw::AdaNode n) {
  result = n.getParent+() and
  not exists(Raw::BaseSubpBody mid | mid = n.getParent+() and mid != result and mid.getParent+() = result)
}

from Raw::SubpBody b, Raw::CallExpr call, Raw::BasicDecl target
where
  b = getInnermostEnclosingSubprogram(call) and
  target = call.(Name).getReferencedDecl() and
  (target = b or target = b.(BaseSubpBody).getDeclaration()) and
  call.(AdaNode).fromSource()
select call, "This call is a direct recursive call."
