/**
 * @name Useless if statement
 * @description An `if` statement whose only branch does nothing (`then null; end if;`,
 *              with no `elsif` or `else`) has no effect and can be removed.
 * @id ada/useless-if
 * @kind problem
 * @problem.severity warning
 * @tags maintainability
 */

import ada

from IfStmt s, StmtList thenStmts
where
  thenStmts = s.getThenStmts() and
  thenStmts.getChild(0) instanceof NullStmt and
  not exists(thenStmts.getChild(1)) and
  not exists(s.getAlternatives().getChild(0)) and
  not exists(s.getElsePart()) and
  // `if Load (X) then null; end if;` calls Load for its effect: it cannot be removed
  not exists(Expr e | e.getParent*() = s.getCondExpr() |
    e instanceof Call or e instanceof CallExpr and not exists(e.(CallExpr).getName().getReferencedDecl())
  ) and
  s.fromSource()
select s, "This if statement does nothing and can be removed."
