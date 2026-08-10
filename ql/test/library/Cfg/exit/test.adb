--  CFG conformance: exit statements.
--  Covers an unconditional exit, "exit when", and a named exit leaving an
--  outer loop from inside an inner one. See docs/cfg-design.md, "Exit".
--
--  An exit is a direct jump edge to the target loop's own node -- the node a
--  PostOrderTree loop uses as its join -- not a completion that propagates.
procedure Exit_Stmt (A, B : Boolean; N : in out Integer) is
begin
   loop
      exit;  -- $ edge=ExitStmt@10:7|break|LoopStmt@9:4
   end loop;  -- $ edge=LoopStmt@9:4|successor|Identifier@14:17

   loop
      exit when A;  -- $ edge=ExitStmt@14:7|break|LoopStmt@13:4 edge=Identifier@14:17|false|Identifier@15:12 edge=Identifier@14:17|true|ExitStmt@14:7
      N := N + 1;  -- $ edge=AssignStmt@15:7|successor|Identifier@14:17 edge=BinOp@15:12|successor|Identifier@15:7 edge=Identifier@15:12|successor|IntLiteral@15:16 edge=Identifier@15:7|successor|AssignStmt@15:7 edge=IntLiteral@15:16|successor|BinOp@15:12
   end loop;  -- $ edge=LoopStmt@13:4|successor|Identifier@20:26

   Outer : loop
      Inner : loop
         exit Outer when B;  -- $ edge=ExitStmt@20:10|break|LoopStmt@18:12 edge=Identifier@20:26|false|ExitStmt@21:10 edge=Identifier@20:26|true|ExitStmt@20:10
         exit Inner;  -- $ edge=ExitStmt@21:10|break|LoopStmt@19:15
      end loop Inner;  -- $ edge=LoopStmt@19:15|successor|Identifier@20:26
   end loop Outer;  -- $ edge=LoopStmt@18:12|successor|exitSubpBody(normal)@7:1
end Exit_Stmt;  -- $ edge=enterSubpBody@7:1|successor|ExitStmt@10:7 edge=exitSubpBody(normal)@7:1|successor|exitSubpBody@7:1
