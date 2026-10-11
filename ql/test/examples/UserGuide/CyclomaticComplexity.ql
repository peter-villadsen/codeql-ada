/**
 * @name Cyclomatic complexity
 * @description McCabe's cyclomatic complexity of each subprogram: one more than the
 *              number of decisions in its body.
 * @kind table
 * @id my-app/cyclomatic-complexity
 */

import ada

/** Holds if `d` is a point where control takes one of two or more ways. */
predicate decision(AdaNode d) {
  d instanceof IfStmt or
  d instanceof ElsifStmtPart or
  d instanceof IfExpr or
  d instanceof ElsifExprPart or
  d instanceof WhileLoopStmt or
  d instanceof ForLoopStmt or
  d instanceof QuantifiedExpr or
  d instanceof ExceptionHandler or
  exists(d.(ExitStmt).getCondExpr()) or
  d.(BinOp).getOp() instanceof OpAndThen or
  d.(BinOp).getOp() instanceof OpOrElse or
  // each alternative of a `case` after the first
  (d instanceof CaseStmtAlternative or d instanceof CaseExprAlternative) and
  not d = d.getParent().getChild(0)
}

from Subprogram s, int complexity
where
  s.fromSource() and
  complexity = 1 + count(AdaNode d | decision(d) and d.getEnclosingSubprogram() = s)
select s, complexity order by complexity desc
