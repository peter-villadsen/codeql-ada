--  CFG conformance: a for loop over a subtype indication.
--  The range expression is evaluated, then the indication, then the loop as usual.
--  See docs/cfg-design.md, "Loops".
procedure For_Subtype (N : Integer; X : in out Integer) is
begin
   for I in Natural range 0 .. N loop  -- $ edge=BinOp@6:27|successor|DiscreteSubtypeIndication@6:13 edge=DiscreteSubtypeIndication@6:13|successor|ForLoopStmt@6:4 edge=DiscreteSubtypeIndication@6:13|successor|Identifier@7:12 edge=Identifier@6:32|successor|BinOp@6:27 edge=IntLiteral@6:27|successor|Identifier@6:32
      X := I;  -- $ edge=AssignStmt@7:7|successor|ForLoopStmt@6:4 edge=AssignStmt@7:7|successor|Identifier@7:12 edge=Identifier@7:12|successor|Identifier@7:7 edge=Identifier@7:7|successor|AssignStmt@7:7
   end loop;  -- $ edge=ForLoopStmt@6:4|successor|IntLiteral@9:9
   X := 0;  -- $ edge=AssignStmt@9:4|successor|exitSubpBody(normal)@4:1 edge=Identifier@9:4|successor|AssignStmt@9:4 edge=IntLiteral@9:9|successor|Identifier@9:4
end For_Subtype;  -- $ edge=enterSubpBody@4:1|successor|IntLiteral@6:27 edge=exitSubpBody(normal)@4:1|successor|exitSubpBody@4:1
