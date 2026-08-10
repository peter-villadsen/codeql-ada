--  CFG conformance: return statements.
--  Covers a return with a value, a bare return from a procedure, and an
--  extended return with a do-block. See docs/cfg-design.md, "Return".
procedure Return_Stmt is

   function Ret (A : Boolean; N : Integer) return Integer is
   begin
      if A then  -- $ edge=Identifier@8:10|false|IfStmt@8:7 edge=Identifier@8:10|true|IntLiteral@9:17
         return 1;  -- $ edge=IntLiteral@9:17|successor|ReturnStmt@9:10 edge=ReturnStmt@9:10|return|exitSubpBody(normal)@6:4
      end if;  -- $ edge=IfStmt@8:7|successor|Identifier@11:14
      return N;  -- $ edge=Identifier@11:14|successor|ReturnStmt@11:7 edge=ReturnStmt@11:7|return|exitSubpBody(normal)@6:4
   end Ret;  -- $ edge=enterSubpBody@6:4|successor|Identifier@8:10 edge=exitSubpBody(normal)@6:4|successor|exitSubpBody@6:4

   procedure Bare (A : Boolean; N : in out Integer) is
   begin
      if A then  -- $ edge=Identifier@16:10|false|IfStmt@16:7 edge=Identifier@16:10|true|ReturnStmt@17:10
         return;  -- $ edge=ReturnStmt@17:10|return|exitSubpBody(normal)@14:4
      end if;  -- $ edge=IfStmt@16:7|successor|IntLiteral@19:12
      N := 0;  -- $ edge=AssignStmt@19:7|successor|exitSubpBody(normal)@14:4 edge=Identifier@19:7|successor|AssignStmt@19:7 edge=IntLiteral@19:12|successor|Identifier@19:7
   end Bare;  -- $ edge=enterSubpBody@14:4|successor|Identifier@16:10 edge=exitSubpBody(normal)@14:4|successor|exitSubpBody@14:4

   function Ext (N : Integer) return Integer is
   begin
      return R : Integer := N do  -- $ edge=Identifier@24:29|successor|Identifier@25:15
         R := R + 1;  -- $ edge=AssignStmt@25:10|successor|ExtendedReturnStmt@24:7 edge=BinOp@25:15|successor|Identifier@25:10 edge=Identifier@25:10|successor|AssignStmt@25:10 edge=Identifier@25:15|successor|IntLiteral@25:19 edge=IntLiteral@25:19|successor|BinOp@25:15
      end return;  -- $ edge=ExtendedReturnStmt@24:7|return|exitSubpBody(normal)@22:4
   end Ext;  -- $ edge=enterSubpBody@22:4|successor|Identifier@24:29 edge=exitSubpBody(normal)@22:4|successor|exitSubpBody@22:4

begin
   null;  -- $ edge=NullStmt@30:4|successor|exitSubpBody(normal)@4:1
end Return_Stmt;  -- $ edge=enterSubpBody@4:1|successor|NullStmt@30:4 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
