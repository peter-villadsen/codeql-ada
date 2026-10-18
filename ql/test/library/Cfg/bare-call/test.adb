--  CFG conformance: a call written without parentheses may raise.
--  `Get` in `return Get;` is a call, so it has an exception edge to the handler,
--  which is therefore reachable.
--  See docs/cfg-design.md, "Exceptions".
function Bare_Call return Integer is
   function Get return Integer is (1);  -- $ edge=IntLiteral@6:36|successor|ParenExpr@6:35 edge=ParenExpr@6:35|successor|after:ParenExpr@6:35 edge=after:ParenExpr@6:35|successor|exitExprFunction(normal)@6:4 edge=before:ParenExpr@6:35|successor|IntLiteral@6:36 edge=enterExprFunction@6:4|successor|before:ParenExpr@6:35 edge=exitExprFunction(normal)@6:4|successor|exitExprFunction@6:4
begin
   return Get;  -- $ edge=Identifier@8:11|exception|ExceptionHandler@10:4 edge=Identifier@8:11|successor|after:Identifier@8:11 edge=ReturnStmt@8:4|return|exitSubpBody(normal)@5:1 edge=StmtList@8:4|successor|before:ReturnStmt@8:4 edge=after:Identifier@8:11|successor|ReturnStmt@8:4 edge=before:Identifier@8:11|successor|Identifier@8:11 edge=before:ReturnStmt@8:4|successor|before:Identifier@8:11
exception
   when others =>
      return 0;  -- $ edge=ExceptionHandler@10:4|match|after-true:ExceptionHandler@10:4 edge=IntLiteral@11:14|successor|ReturnStmt@11:7 edge=ReturnStmt@11:7|return|exitSubpBody(normal)@5:1 edge=StmtList@11:7|successor|before:ReturnStmt@11:7 edge=after-true:ExceptionHandler@10:4|successor|StmtList@11:7 edge=before:ReturnStmt@11:7|successor|IntLiteral@11:14
end Bare_Call;  -- $ edge=HandledStmts@7:6|successor|StmtList@8:4 edge=enterSubpBody@5:1|successor|HandledStmts@7:6 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
