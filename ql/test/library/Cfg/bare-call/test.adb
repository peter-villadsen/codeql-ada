--  CFG conformance: a call written without parentheses may raise.
--  `Get` in `return Get;` is a call, so it has an exception edge to the handler,
--  which is therefore reachable.
--  See docs/cfg-design.md, "Exceptions".
function Bare_Call return Integer is
   function Get return Integer is (1);  -- $ edge=IntLiteral@6:36|successor|ParenExpr@6:35 edge=ParenExpr@6:35|successor|exitExprFunction(normal)@6:4 edge=enterExprFunction@6:4|successor|IntLiteral@6:36 edge=exitExprFunction(normal)@6:4|successor|exitExprFunction@6:4
begin
   return Get;  -- $ edge=Identifier@8:11|exception|IntLiteral@11:14 edge=Identifier@8:11|successor|ReturnStmt@8:4 edge=ReturnStmt@8:4|return|exitSubpBody(normal)@5:1
exception
   when others =>
      return 0;  -- $ edge=IntLiteral@11:14|successor|ReturnStmt@11:7 edge=ReturnStmt@11:7|return|exitSubpBody(normal)@5:1
end Bare_Call;  -- $ edge=enterSubpBody@5:1|successor|Identifier@8:11 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
