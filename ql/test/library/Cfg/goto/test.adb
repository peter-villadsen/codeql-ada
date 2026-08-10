--  CFG conformance: goto statements and labels.
--  Covers a backward goto, a forward goto, and the statement made unreachable
--  by an unconditional goto. See docs/cfg-design.md, "Goto and labels".
procedure Goto_Stmt (A : Boolean; N : in out Integer) is
begin
   <<Again>>  -- $ edge=Label@6:4|successor|Identifier@7:9
   N := N + 1;  -- $ edge=AssignStmt@7:4|successor|Identifier@8:7 edge=BinOp@7:9|successor|Identifier@7:4 edge=Identifier@7:4|successor|AssignStmt@7:4 edge=Identifier@7:9|successor|IntLiteral@7:13 edge=IntLiteral@7:13|successor|BinOp@7:9
   if A then  -- $ edge=Identifier@8:7|false|IfStmt@8:4 edge=Identifier@8:7|true|GotoStmt@9:7
      goto Again;  -- $ edge=GotoStmt@9:7|goto|Label@6:4
   end if;  -- $ edge=IfStmt@8:4|successor|GotoStmt@12:4

   goto Done;  -- $ edge=GotoStmt@12:4|goto|Label@14:4
   N := 999;
   <<Done>>  -- $ edge=Label@14:4|successor|NullStmt@15:4
   null;  -- $ edge=NullStmt@15:4|successor|exitSubpBody(normal)@4:1
end Goto_Stmt;  -- $ edge=enterSubpBody@4:1|successor|Label@6:4 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
