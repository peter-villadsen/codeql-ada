--  CFG conformance: return statements.
--  Covers a return with a value, a bare return from a procedure, and an
--  extended return with a do-block. See docs/cfg-design.md, "Return".
procedure Return_Stmt is

   function Ret (A : Boolean; N : Integer) return Integer is
   begin
      if A then  -- $ edge=Identifier@8:10|false|after-false:Identifier@8:10 edge=Identifier@8:10|true|after-true:Identifier@8:10 edge=after-false:Identifier@8:10|successor|after:IfStmt@8:7 edge=after-true:Identifier@8:10|successor|StmtList@9:10
         return 1;  -- $ edge=IntLiteral@9:17|successor|ReturnStmt@9:10 edge=ReturnStmt@9:10|return|exitSubpBody(normal)@6:4 edge=StmtList@9:10|successor|before:ReturnStmt@9:10 edge=before:ReturnStmt@9:10|successor|IntLiteral@9:17
      end if;  -- $ edge=IfStmt@8:7|successor|Identifier@8:10 edge=after:IfStmt@8:7|successor|before:ReturnStmt@11:7
      return N;  -- $ edge=Identifier@11:14|successor|ReturnStmt@11:7 edge=ReturnStmt@11:7|return|exitSubpBody(normal)@6:4 edge=StmtList@8:7|successor|IfStmt@8:7 edge=before:ReturnStmt@11:7|successor|Identifier@11:14
   end Ret;  -- $ edge=HandledStmts@7:9|successor|StmtList@8:7 edge=enterSubpBody@6:4|successor|HandledStmts@7:9 edge=exitSubpBody(normal)@6:4|successor|exitSubpBody@6:4

   procedure Bare (A : Boolean; N : in out Integer) is
   begin
      if A then  -- $ edge=Identifier@16:10|false|after-false:Identifier@16:10 edge=Identifier@16:10|true|after-true:Identifier@16:10 edge=after-false:Identifier@16:10|successor|after:IfStmt@16:7 edge=after-true:Identifier@16:10|successor|StmtList@17:10
         return;  -- $ edge=ReturnStmt@17:10|return|exitSubpBody(normal)@14:4 edge=StmtList@17:10|successor|before:ReturnStmt@17:10 edge=before:ReturnStmt@17:10|successor|ReturnStmt@17:10
      end if;  -- $ edge=IfStmt@16:7|successor|Identifier@16:10 edge=after:IfStmt@16:7|successor|before:AssignStmt@19:7
      N := 0;  -- $ edge=AssignStmt@19:7|successor|after:AssignStmt@19:7 edge=Identifier@19:7|successor|AssignStmt@19:7 edge=IntLiteral@19:12|successor|Identifier@19:7 edge=StmtList@16:7|successor|IfStmt@16:7 edge=after:AssignStmt@19:7|successor|after:StmtList@16:7 edge=after:StmtList@16:7|successor|after:HandledStmts@15:9 edge=before:AssignStmt@19:7|successor|IntLiteral@19:12
   end Bare;  -- $ edge=HandledStmts@15:9|successor|StmtList@16:7 edge=after:HandledStmts@15:9|successor|exitSubpBody(normal)@14:4 edge=enterSubpBody@14:4|successor|HandledStmts@15:9 edge=exitSubpBody(normal)@14:4|successor|exitSubpBody@14:4

   function Ext (N : Integer) return Integer is
   begin
      return R : Integer := N do  -- $ edge=Identifier@24:29|successor|HandledStmts@24:33
         R := R + 1;  -- $ edge=AssignStmt@25:10|successor|after:AssignStmt@25:10 edge=BinOp@25:15|successor|after:BinOp@25:15 edge=Identifier@25:10|successor|AssignStmt@25:10 edge=Identifier@25:15|successor|IntLiteral@25:19 edge=IntLiteral@25:19|successor|BinOp@25:15 edge=StmtList@25:10|successor|before:AssignStmt@25:10 edge=after:AssignStmt@25:10|successor|after:StmtList@25:10 edge=after:BinOp@25:15|successor|Identifier@25:10 edge=after:StmtList@25:10|successor|after:HandledStmts@24:33 edge=before:AssignStmt@25:10|successor|before:BinOp@25:15 edge=before:BinOp@25:15|successor|Identifier@25:15
      end return;  -- $ edge=ExtendedReturnStmt@24:7|return|exitSubpBody(normal)@22:4 edge=HandledStmts@24:33|successor|StmtList@25:10 edge=StmtList@24:7|successor|before:ExtendedReturnStmt@24:7 edge=after:HandledStmts@24:33|successor|ExtendedReturnStmt@24:7 edge=before:ExtendedReturnStmt@24:7|successor|Identifier@24:29
   end Ext;  -- $ edge=HandledStmts@23:9|successor|StmtList@24:7 edge=enterSubpBody@22:4|successor|HandledStmts@23:9 edge=exitSubpBody(normal)@22:4|successor|exitSubpBody@22:4

begin
   null;  -- $ edge=NullStmt@30:4|successor|after:StmtList@30:4 edge=StmtList@30:4|successor|NullStmt@30:4 edge=after:StmtList@30:4|successor|after:HandledStmts@29:6
end Return_Stmt;  -- $ edge=HandledStmts@29:6|successor|StmtList@30:4 edge=after:HandledStmts@29:6|successor|exitSubpBody(normal)@4:1 edge=enterSubpBody@4:1|successor|HandledStmts@29:6 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
