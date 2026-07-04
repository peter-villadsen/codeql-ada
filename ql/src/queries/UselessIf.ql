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

from Raw::IfStmt s, Raw::StmtList thenStmts
where
  thenStmts = s.getThenStmts() and
  thenStmts.getChild(0) instanceof Raw::NullStmt and
  not exists(thenStmts.getChild(1)) and
  not exists(s.getAlternatives().getChild(0)) and
  not exists(s.getElsePart())
select s, "This if statement does nothing and can be removed."
