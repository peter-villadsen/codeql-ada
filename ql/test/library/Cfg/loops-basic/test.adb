--  CFG conformance: plain and while loops.
--  See docs/cfg-design.md, "Plain and while loops".
--
--  The second loop has no exit, so its LoopStmt node is unreachable and the
--  procedure never completes normally: there is no exit (normal) node.
procedure Loops_Basic (A : Boolean; N : in out Integer) is
begin
   while A loop  -- $ edge=Identifier@8:10|false|after-false:Identifier@8:10 edge=Identifier@8:10|true|after-true:Identifier@8:10 edge=after-false:Identifier@8:10|successor|after:WhileLoopStmt@8:4 edge=after-true:Identifier@8:10|successor|StmtList@9:7
      N := N + 1;  -- $ edge=AssignStmt@9:7|successor|after:AssignStmt@9:7 edge=BinOp@9:12|successor|after:BinOp@9:12 edge=Identifier@9:12|successor|IntLiteral@9:16 edge=Identifier@9:7|successor|AssignStmt@9:7 edge=IntLiteral@9:16|successor|BinOp@9:12 edge=StmtList@9:7|successor|before:AssignStmt@9:7 edge=after:AssignStmt@9:7|successor|after:StmtList@9:7 edge=after:BinOp@9:12|successor|Identifier@9:7 edge=after:StmtList@9:7|successor|add.[LoopHeader]:WhileLoopStmt@8:4 edge=before:AssignStmt@9:7|successor|before:BinOp@9:12 edge=before:BinOp@9:12|successor|Identifier@9:12
   end loop;  -- $ edge=WhileLoopStmt@8:4|successor|add.[LoopHeader]:WhileLoopStmt@8:4 edge=add.[LoopHeader]:WhileLoopStmt@8:4|successor|Identifier@8:10 edge=after:WhileLoopStmt@8:4|successor|LoopStmt@12:4

   loop
      N := N + 1;  -- $ edge=AssignStmt@13:7|successor|after:AssignStmt@13:7 edge=BinOp@13:12|successor|after:BinOp@13:12 edge=Identifier@13:12|successor|IntLiteral@13:16 edge=Identifier@13:7|successor|AssignStmt@13:7 edge=IntLiteral@13:16|successor|BinOp@13:12 edge=StmtList@13:7|successor|before:AssignStmt@13:7 edge=after:AssignStmt@13:7|successor|after:StmtList@13:7 edge=after:BinOp@13:12|successor|Identifier@13:7 edge=after:StmtList@13:7|successor|add.[LoopHeader]:LoopStmt@12:4 edge=before:AssignStmt@13:7|successor|before:BinOp@13:12 edge=before:BinOp@13:12|successor|Identifier@13:12
   end loop;  -- $ edge=LoopStmt@12:4|successor|add.[LoopHeader]:LoopStmt@12:4 edge=StmtList@8:4|successor|WhileLoopStmt@8:4 edge=add.[LoopHeader]:LoopStmt@12:4|successor|StmtList@13:7
end Loops_Basic;  -- $ edge=HandledStmts@7:6|successor|StmtList@8:4 edge=enterSubpBody@6:1|successor|HandledStmts@7:6
