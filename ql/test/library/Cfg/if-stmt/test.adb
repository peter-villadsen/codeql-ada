--  CFG conformance: if statements.
--  Covers if/elsif/else, an if with no else falling through to the join, and a
--  condition that can raise. See docs/cfg-design.md, "If statement".
--
--  The third if exists for contrast with the case statement: IfStmtTree lists
--  its guard conditions in propagatesAbnormal, so the call in the condition
--  gets an exception edge. The same call in a case selector does not -- see
--  the case-stmt family.
procedure If_Stmt (A, B : Boolean; N : in out Integer) is
   function Check (X : Integer) return Boolean is (X > 0);  -- $ edge=Identifier@10:52|successor|IntLiteral@10:56 edge=IntLiteral@10:56|successor|RelationOp@10:52 edge=ParenExpr@10:51|successor|exitExprFunction(normal)@10:4 edge=RelationOp@10:52|successor|ParenExpr@10:51 edge=enterExprFunction@10:4|successor|Identifier@10:52 edge=exitExprFunction(normal)@10:4|successor|exitExprFunction@10:4
begin
   if A then  -- $ edge=Identifier@12:7|false|Identifier@14:10 edge=Identifier@12:7|true|IntLiteral@13:12
      N := 1;  -- $ edge=AssignStmt@13:7|successor|IfStmt@12:4 edge=Identifier@13:7|successor|AssignStmt@13:7 edge=IntLiteral@13:12|successor|Identifier@13:7
   elsif B then  -- $ edge=Identifier@14:10|false|IntLiteral@17:12 edge=Identifier@14:10|true|IntLiteral@15:12
      N := 2;  -- $ edge=AssignStmt@15:7|successor|IfStmt@12:4 edge=Identifier@15:7|successor|AssignStmt@15:7 edge=IntLiteral@15:12|successor|Identifier@15:7
   else
      N := 3;  -- $ edge=AssignStmt@17:7|successor|IfStmt@12:4 edge=Identifier@17:7|successor|AssignStmt@17:7 edge=IntLiteral@17:12|successor|Identifier@17:7
   end if;  -- $ edge=IfStmt@12:4|successor|Identifier@20:7

   if A then  -- $ edge=Identifier@20:7|false|IfStmt@20:4 edge=Identifier@20:7|true|IntLiteral@21:12
      N := 4;  -- $ edge=AssignStmt@21:7|successor|IfStmt@20:4 edge=Identifier@21:7|successor|AssignStmt@21:7 edge=IntLiteral@21:12|successor|Identifier@21:7
   end if;  -- $ edge=IfStmt@20:4|successor|Identifier@24:7

   if Check (N) then  -- $ edge=AssocList@24:14|successor|CallExpr@24:7 edge=CallExpr@24:7|exception|exitSubpBody(abnormal)@9:1 edge=CallExpr@24:7|false|IfStmt@24:4 edge=CallExpr@24:7|true|IntLiteral@25:12 edge=Identifier@24:14|successor|ParamAssoc@24:14 edge=Identifier@24:7|successor|Identifier@24:14 edge=ParamAssoc@24:14|successor|AssocList@24:14
      N := 5;  -- $ edge=AssignStmt@25:7|successor|IfStmt@24:4 edge=Identifier@25:7|successor|AssignStmt@25:7 edge=IntLiteral@25:12|successor|Identifier@25:7
   end if;  -- $ edge=IfStmt@24:4|successor|exitSubpBody(normal)@9:1
end If_Stmt;  -- $ edge=enterSubpBody@9:1|successor|Identifier@12:7 edge=exitSubpBody(abnormal)@9:1|successor|exitSubpBody@9:1 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
