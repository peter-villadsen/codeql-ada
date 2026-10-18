--  CFG conformance: goto statements and labels.
--  Covers a backward goto, a forward goto, and the statement made unreachable
--  by an unconditional goto. See docs/cfg-design.md, "Goto and labels".
procedure Goto_Stmt (A : Boolean; N : in out Integer) is
begin
   <<Again>>  -- $ edge=Label@6:4|successor|before:AssignStmt@7:4
   N := N + 1;  -- $ edge=AssignStmt@7:4|successor|after:AssignStmt@7:4 edge=BinOp@7:9|successor|after:BinOp@7:9 edge=Identifier@7:4|successor|AssignStmt@7:4 edge=Identifier@7:9|successor|IntLiteral@7:13 edge=IntLiteral@7:13|successor|BinOp@7:9 edge=after:AssignStmt@7:4|successor|IfStmt@8:4 edge=after:BinOp@7:9|successor|Identifier@7:4 edge=before:AssignStmt@7:4|successor|before:BinOp@7:9 edge=before:BinOp@7:9|successor|Identifier@7:9
   if A then  -- $ edge=Identifier@8:7|false|after-false:Identifier@8:7 edge=Identifier@8:7|true|after-true:Identifier@8:7 edge=after-false:Identifier@8:7|successor|after:IfStmt@8:4 edge=after-true:Identifier@8:7|successor|StmtList@9:7
      goto Again;  -- $ edge=GotoStmt@9:7|goto|Label@6:4 edge=StmtList@9:7|successor|before:GotoStmt@9:7 edge=before:GotoStmt@9:7|successor|GotoStmt@9:7
   end if;  -- $ edge=IfStmt@8:4|successor|Identifier@8:7 edge=after:IfStmt@8:4|successor|before:GotoStmt@12:4

   goto Done;  -- $ edge=GotoStmt@12:4|goto|Label@14:4 edge=before:GotoStmt@12:4|successor|GotoStmt@12:4
   N := 999;
   <<Done>>  -- $ edge=Label@14:4|successor|NullStmt@15:4
   null;  -- $ edge=NullStmt@15:4|successor|after:StmtList@6:4 edge=StmtList@6:4|successor|Label@6:4 edge=after:StmtList@6:4|successor|after:HandledStmts@5:6
end Goto_Stmt;  -- $ edge=HandledStmts@5:6|successor|StmtList@6:4 edge=after:HandledStmts@5:6|successor|exitSubpBody(normal)@4:1 edge=enterSubpBody@4:1|successor|HandledStmts@5:6 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
