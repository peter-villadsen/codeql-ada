--  CFG conformance: pragmas among statements.
--  A pragma is a leaf that completes normally; its arguments are not evaluated.
--  The statements after it are reachable.
--  See docs/cfg-design.md, "Linear code".
procedure Pragmas (X : in out Integer) is
begin
   X := 1;  -- $ edge=AssignStmt@7:4|successor|after:AssignStmt@7:4 edge=Identifier@7:4|successor|AssignStmt@7:4 edge=IntLiteral@7:9|successor|Identifier@7:4 edge=after:AssignStmt@7:4|successor|PragmaNode@8:4 edge=before:AssignStmt@7:4|successor|IntLiteral@7:9
   pragma Assert (X = 1);  -- $ edge=PragmaNode@8:4|successor|before:AssignStmt@9:4
   X := 2;  -- $ edge=AssignStmt@9:4|successor|after:AssignStmt@9:4 edge=Identifier@9:4|successor|AssignStmt@9:4 edge=IntLiteral@9:9|successor|Identifier@9:4 edge=StmtList@7:4|successor|before:AssignStmt@7:4 edge=after:AssignStmt@9:4|successor|after:StmtList@7:4 edge=after:StmtList@7:4|successor|after:HandledStmts@6:6 edge=before:AssignStmt@9:4|successor|IntLiteral@9:9
end Pragmas;  -- $ edge=HandledStmts@6:6|successor|StmtList@7:4 edge=after:HandledStmts@6:6|successor|exitSubpBody(normal)@5:1 edge=enterSubpBody@5:1|successor|HandledStmts@6:6 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
