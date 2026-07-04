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
 * Gets the declarative region "containing" `n`, for the purpose of finding sibling
 * declarations. For a nested declaration this is just its parent (the shared
 * `AdaNodeList` of a `DeclarativePart`). A library-level (top-level) declaration is
 * instead wrapped in its own private `LibraryItem`/`CompilationUnit` pair - two distinct
 * top-level siblings do NOT share a parent at that level (confirmed by inspecting the
 * AST), only three levels up at the file's shared `CompilationUnitList` - so that case is
 * special-cased here.
 */
private Raw::AdaNode getEnclosingRegion(Raw::AdaNode n) {
  exists(Raw::AdaNode p | p = n.getParent() |
    p instanceof Raw::LibraryItem and result = p.getParent().getParent()
    or
    not p instanceof Raw::LibraryItem and result = p
  )
}

/**
 * Gets the separate forward declaration for `body`, if any, approximated by matching name
 * text within the same declarative region - the schema has no direct decl-body link (same
 * approximation as `ada/dead-local-subprogram`).
 */
private Raw::SubpDecl getMatchingDecl(Raw::SubpBody body) {
  getEnclosingRegion(result) = getEnclosingRegion(body) and
  result.(BasicDecl).getAName() = body.(BasicDecl).getAName()
}

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
  (target = b or target = getMatchingDecl(b))
select call, "This call is a direct recursive call."
