--  CFG conformance: short-circuit operators.
--  Covers "and then", "or else", a nested combination, and plain "and" for
--  contrast. See docs/cfg-design.md, "Short-circuit operators".
procedure Short_Circuit (A, B, C : Boolean; N : out Integer) is
begin
   if A and then B then  -- $ edge=BinOp@6:7|false|IfStmt@6:4 edge=BinOp@6:7|true|IntLiteral@7:12 edge=Identifier@6:18|successor|BinOp@6:7 edge=Identifier@6:7|false|BinOp@6:7 edge=Identifier@6:7|true|Identifier@6:18
      N := 1;  -- $ edge=AssignStmt@7:7|successor|IfStmt@6:4 edge=Identifier@7:7|successor|AssignStmt@7:7 edge=IntLiteral@7:12|successor|Identifier@7:7
   end if;  -- $ edge=IfStmt@6:4|successor|Identifier@10:7

   if A or else B then  -- $ edge=BinOp@10:7|false|IfStmt@10:4 edge=BinOp@10:7|true|IntLiteral@11:12 edge=Identifier@10:17|successor|BinOp@10:7 edge=Identifier@10:7|false|Identifier@10:17 edge=Identifier@10:7|true|BinOp@10:7
      N := 2;  -- $ edge=AssignStmt@11:7|successor|IfStmt@10:4 edge=Identifier@11:7|successor|AssignStmt@11:7 edge=IntLiteral@11:12|successor|Identifier@11:7
   end if;  -- $ edge=IfStmt@10:4|successor|Identifier@14:7

   if A and then (B or else C) then  -- $ edge=BinOp@14:19|successor|ParenExpr@14:18 edge=BinOp@14:7|false|IfStmt@14:4 edge=BinOp@14:7|true|IntLiteral@15:12 edge=Identifier@14:19|false|Identifier@14:29 edge=Identifier@14:19|true|BinOp@14:19 edge=Identifier@14:29|successor|BinOp@14:19 edge=Identifier@14:7|false|BinOp@14:7 edge=Identifier@14:7|true|Identifier@14:19 edge=ParenExpr@14:18|successor|BinOp@14:7
      N := 3;  -- $ edge=AssignStmt@15:7|successor|IfStmt@14:4 edge=Identifier@15:7|successor|AssignStmt@15:7 edge=IntLiteral@15:12|successor|Identifier@15:7
   end if;  -- $ edge=IfStmt@14:4|successor|Identifier@18:7

   if A and B then  -- $ edge=BinOp@18:7|false|IfStmt@18:4 edge=BinOp@18:7|true|IntLiteral@19:12 edge=Identifier@18:13|successor|BinOp@18:7 edge=Identifier@18:7|successor|Identifier@18:13
      N := 4;  -- $ edge=AssignStmt@19:7|successor|IfStmt@18:4 edge=Identifier@19:7|successor|AssignStmt@19:7 edge=IntLiteral@19:12|successor|Identifier@19:7
   end if;  -- $ edge=IfStmt@18:4|successor|exitSubpBody(normal)@4:1
end Short_Circuit;  -- $ edge=enterSubpBody@4:1|successor|Identifier@6:7 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
