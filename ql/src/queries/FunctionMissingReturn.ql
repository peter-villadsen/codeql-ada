/**
 * @name Function missing return
 * @description A function body whose control flow can fall off the end without
 *              executing a `return` statement raises `Program_Error` at run time --
 *              legal to compile, but always a bug.
 * @id ada/function-missing-return
 * @kind problem
 * @problem.severity error
 * @tags correctness
 */

import ada
import codeql.ada.controlflow.Cfg

/** Holds if some statement in `body` falls through (not via `return`) to the scope exit. */
private predicate fallsOffEnd(Raw::SubpBody body) {
  exists(AstCfgNode last, AnnotatedExitNode exit, DirectSuccessor t |
    last.getASuccessor(t) = exit and
    exit.getScope() = body
  )
}

from Raw::SubpBody body
where
  body.getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
  fallsOffEnd(body)
select body,
  "This function may run off the end without executing a return statement, which raises Program_Error at run time."
