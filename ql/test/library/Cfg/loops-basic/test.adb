--  CFG conformance: plain and while loops.
--  See docs/cfg-design.md, "Plain and while loops".
--
--  The second loop has no exit, so its LoopStmt node is unreachable and the
--  procedure never completes normally: there is no exit (normal) node.
procedure Loops_Basic (A : Boolean; N : in out Integer) is
begin
   while A loop  -- $ edge=Identifier@8:10|false|WhileLoopStmt@8:4 edge=Identifier@8:10|true|Identifier@9:12
      N := N + 1;  -- $ edge=AssignStmt@9:7|successor|Identifier@8:10 edge=BinOp@9:12|successor|Identifier@9:7 edge=Identifier@9:12|successor|IntLiteral@9:16 edge=Identifier@9:7|successor|AssignStmt@9:7 edge=IntLiteral@9:16|successor|BinOp@9:12
   end loop;  -- $ edge=WhileLoopStmt@8:4|successor|Identifier@13:12

   loop
      N := N + 1;  -- $ edge=AssignStmt@13:7|successor|Identifier@13:12 edge=BinOp@13:12|successor|Identifier@13:7 edge=Identifier@13:12|successor|IntLiteral@13:16 edge=Identifier@13:7|successor|AssignStmt@13:7 edge=IntLiteral@13:16|successor|BinOp@13:12
   end loop;
end Loops_Basic;  -- $ edge=enterSubpBody@6:1|successor|Identifier@8:10
