--  CFG conformance: case statements.
--  Covers a case with three alternatives (including others) and a case whose
--  selector is a call. See docs/cfg-design.md, "Case statement".
--
--  Note what the second case does NOT produce: no exception edge out of
--  Id (N), even though every call is assumed to be able to raise. That is
--  candidate defect C-2 -- CaseStmtTree omits the selector from
--  propagatesAbnormal -- recorded as a MISSING expectation below.
procedure Case_Stmt (N : Integer; R : out Integer) is
   function Id (X : Integer) return Integer is (X);  -- $ edge=Identifier@10:49|successor|ParenExpr@10:48 edge=ParenExpr@10:48|successor|exitExprFunction(normal)@10:4 edge=enterExprFunction@10:4|successor|Identifier@10:49 edge=exitExprFunction(normal)@10:4|successor|exitExprFunction@10:4
begin
   case N is  -- $ edge=Identifier@12:9|successor|IntLiteral@14:15 edge=Identifier@12:9|successor|IntLiteral@16:15 edge=Identifier@12:9|successor|IntLiteral@18:15
      when 0 =>
         R := 10;  -- $ edge=AssignStmt@14:10|successor|CaseStmt@12:4 edge=Identifier@14:10|successor|AssignStmt@14:10 edge=IntLiteral@14:15|successor|Identifier@14:10
      when 1 =>
         R := 11;  -- $ edge=AssignStmt@16:10|successor|CaseStmt@12:4 edge=Identifier@16:10|successor|AssignStmt@16:10 edge=IntLiteral@16:15|successor|Identifier@16:10
      when others =>
         R := 12;  -- $ edge=AssignStmt@18:10|successor|CaseStmt@12:4 edge=Identifier@18:10|successor|AssignStmt@18:10 edge=IntLiteral@18:15|successor|Identifier@18:10
   end case;  -- $ edge=CaseStmt@12:4|successor|Identifier@21:9

   case Id (N) is  -- $ edge=AssocList@21:13|successor|CallExpr@21:9 edge=CallExpr@21:9|successor|IntLiteral@23:15 edge=Identifier@21:13|successor|ParamAssoc@21:13 edge=Identifier@21:9|successor|Identifier@21:13 edge=ParamAssoc@21:13|successor|AssocList@21:13 MISSING: edge=CallExpr@21:9|exception|exitSubpBody(abnormal)@9:1
      when others =>
         R := 20;  -- $ edge=AssignStmt@23:10|successor|CaseStmt@21:4 edge=Identifier@23:10|successor|AssignStmt@23:10 edge=IntLiteral@23:15|successor|Identifier@23:10
   end case;  -- $ edge=CaseStmt@21:4|successor|exitSubpBody(normal)@9:1
end Case_Stmt;  -- $ edge=enterSubpBody@9:1|successor|Identifier@12:9 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1 MISSING: edge=exitSubpBody(abnormal)@9:1|successor|exitSubpBody@9:1
