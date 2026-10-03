--  CFG conformance: pragmas among statements.
--  A pragma is a leaf that completes normally; its arguments are not evaluated.
--  The statements after it are reachable.
--  See docs/cfg-design.md, "Linear code".
procedure Pragmas (X : in out Integer) is
begin
   X := 1;  -- $ edge=AssignStmt@7:4|successor|PragmaNode@8:4 edge=Identifier@7:4|successor|AssignStmt@7:4 edge=IntLiteral@7:9|successor|Identifier@7:4
   pragma Assert (X = 1);  -- $ edge=PragmaNode@8:4|successor|IntLiteral@9:9
   X := 2;  -- $ edge=AssignStmt@9:4|successor|exitSubpBody(normal)@5:1 edge=Identifier@9:4|successor|AssignStmt@9:4 edge=IntLiteral@9:9|successor|Identifier@9:4
end Pragmas;  -- $ edge=enterSubpBody@5:1|successor|IntLiteral@7:9 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
