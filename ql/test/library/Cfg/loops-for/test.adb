--  CFG conformance: for loops, both the range form and the iterator form.
--  See docs/cfg-design.md, "For loops".
--
--  The iteration mechanism is opaque (D-013): the iterable is evaluated once,
--  then control may enter the body or skip the loop entirely, and after each
--  iteration may loop again or leave.
procedure Loops_For (N : in out Integer) is
   type Vec is array (1 .. 3) of Integer;
   V : Vec := (others => 0);
begin
   for I in 1 .. 3 loop  -- $ edge=BinOp@11:13|successor|ForLoopStmt@11:4 edge=BinOp@11:13|successor|Identifier@12:12 edge=IntLiteral@11:13|successor|IntLiteral@11:18 edge=IntLiteral@11:18|successor|BinOp@11:13
      N := N + I;  -- $ edge=AssignStmt@12:7|successor|ForLoopStmt@11:4 edge=AssignStmt@12:7|successor|Identifier@12:12 edge=BinOp@12:12|successor|Identifier@12:7 edge=Identifier@12:12|successor|Identifier@12:16 edge=Identifier@12:16|successor|BinOp@12:12 edge=Identifier@12:7|successor|AssignStmt@12:7
   end loop;  -- $ edge=ForLoopStmt@11:4|successor|Identifier@15:13

   for E of V loop  -- $ edge=Identifier@15:13|successor|ForLoopStmt@15:4 edge=Identifier@15:13|successor|Identifier@16:12
      N := N + E;  -- $ edge=AssignStmt@16:7|successor|ForLoopStmt@15:4 edge=AssignStmt@16:7|successor|Identifier@16:12 edge=BinOp@16:12|successor|Identifier@16:7 edge=Identifier@16:12|successor|Identifier@16:16 edge=Identifier@16:16|successor|BinOp@16:12 edge=Identifier@16:7|successor|AssignStmt@16:7
   end loop;  -- $ edge=ForLoopStmt@15:4|successor|exitSubpBody(normal)@7:1
end Loops_For;  -- $ edge=enterSubpBody@7:1|successor|IntLiteral@11:13 edge=exitSubpBody(normal)@7:1|successor|exitSubpBody@7:1
