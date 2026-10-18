--  CFG conformance: exit statements.
--  Covers an unconditional exit, "exit when", and a named exit leaving an
--  outer loop from inside an inner one. See docs/cfg-design.md, "Exit".
--
--  An exit is a break labelled with the loop it leaves: it propagates out to that
--  loop, whose "after" node it reaches, and no construct in between catches it.
procedure Exit_Stmt (A, B : Boolean; N : in out Integer) is
begin
   loop
      exit;  -- $ edge=ExitStmt@10:7|break|after:LoopStmt@9:4 edge=StmtList@10:7|successor|before:ExitStmt@10:7 edge=before:ExitStmt@10:7|successor|ExitStmt@10:7
   end loop;  -- $ edge=LoopStmt@9:4|successor|add.[LoopHeader]:LoopStmt@9:4 edge=add.[LoopHeader]:LoopStmt@9:4|successor|StmtList@10:7 edge=after:LoopStmt@9:4|successor|LoopStmt@13:4

   loop
      exit when A;  -- $ edge=ExitStmt@14:7|break|after:LoopStmt@13:4 edge=Identifier@14:17|false|after-false:Identifier@14:17 edge=Identifier@14:17|true|after-true:Identifier@14:17 edge=after-false:Identifier@14:17|successor|after:ExitStmt@14:7 edge=after-true:Identifier@14:17|successor|ExitStmt@14:7 edge=after:ExitStmt@14:7|successor|before:AssignStmt@15:7 edge=before:ExitStmt@14:7|successor|Identifier@14:17
      N := N + 1;  -- $ edge=AssignStmt@15:7|successor|after:AssignStmt@15:7 edge=BinOp@15:12|successor|after:BinOp@15:12 edge=Identifier@15:12|successor|IntLiteral@15:16 edge=Identifier@15:7|successor|AssignStmt@15:7 edge=IntLiteral@15:16|successor|BinOp@15:12 edge=StmtList@14:7|successor|before:ExitStmt@14:7 edge=after:AssignStmt@15:7|successor|after:StmtList@14:7 edge=after:BinOp@15:12|successor|Identifier@15:7 edge=after:StmtList@14:7|successor|add.[LoopHeader]:LoopStmt@13:4 edge=before:AssignStmt@15:7|successor|before:BinOp@15:12 edge=before:BinOp@15:12|successor|Identifier@15:12
   end loop;  -- $ edge=LoopStmt@13:4|successor|add.[LoopHeader]:LoopStmt@13:4 edge=add.[LoopHeader]:LoopStmt@13:4|successor|StmtList@14:7 edge=after:LoopStmt@13:4|successor|NamedStmt@18:4

   Outer : loop
      Inner : loop
         exit Outer when B;  -- $ edge=ExitStmt@20:10|break|after:LoopStmt@18:12 edge=Identifier@20:26|false|after-false:Identifier@20:26 edge=Identifier@20:26|true|after-true:Identifier@20:26 edge=after-false:Identifier@20:26|successor|after:ExitStmt@20:10 edge=after-true:Identifier@20:26|successor|ExitStmt@20:10 edge=after:ExitStmt@20:10|successor|before:ExitStmt@21:10 edge=before:ExitStmt@20:10|successor|Identifier@20:26
         exit Inner;  -- $ edge=ExitStmt@21:10|break|after:LoopStmt@19:15 edge=StmtList@20:10|successor|before:ExitStmt@20:10 edge=before:ExitStmt@21:10|successor|ExitStmt@21:10
      end loop Inner;  -- $ edge=LoopStmt@19:15|successor|add.[LoopHeader]:LoopStmt@19:15 edge=NamedStmt@19:7|successor|LoopStmt@19:15 edge=StmtList@19:7|successor|NamedStmt@19:7 edge=add.[LoopHeader]:LoopStmt@19:15|successor|StmtList@20:10 edge=after:LoopStmt@19:15|successor|after:NamedStmt@19:7 edge=after:NamedStmt@19:7|successor|after:StmtList@19:7 edge=after:StmtList@19:7|successor|add.[LoopHeader]:LoopStmt@18:12
   end loop Outer;  -- $ edge=LoopStmt@18:12|successor|add.[LoopHeader]:LoopStmt@18:12 edge=NamedStmt@18:4|successor|LoopStmt@18:12 edge=StmtList@9:4|successor|LoopStmt@9:4 edge=add.[LoopHeader]:LoopStmt@18:12|successor|StmtList@19:7 edge=after:LoopStmt@18:12|successor|after:NamedStmt@18:4 edge=after:NamedStmt@18:4|successor|after:StmtList@9:4 edge=after:StmtList@9:4|successor|after:HandledStmts@8:6
end Exit_Stmt;  -- $ edge=HandledStmts@8:6|successor|StmtList@9:4 edge=after:HandledStmts@8:6|successor|exitSubpBody(normal)@7:1 edge=enterSubpBody@7:1|successor|HandledStmts@8:6 edge=exitSubpBody(normal)@7:1|successor|exitSubpBody@7:1
