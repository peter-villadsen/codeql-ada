--  CFG conformance: case statements.
--  Covers a case with three alternatives (including others) and a case whose
--  selector is a call. See docs/cfg-design.md, "Case statement".
--
--  The second case pins the fix for defect C-2: CaseStmtTree now lists the
--  selector in propagatesAbnormal, so a selector that can raise gets an
--  exception edge, matching an if statement guard condition.
procedure Case_Stmt (N : Integer; R : out Integer) is
   function Id (X : Integer) return Integer is (X);  -- $ edge=Identifier@9:49|successor|ParenExpr@9:48 edge=ParenExpr@9:48|successor|exitExprFunction(normal)@9:4 edge=enterExprFunction@9:4|successor|Identifier@9:49 edge=exitExprFunction(normal)@9:4|successor|exitExprFunction@9:4
begin
   case N is  -- $ edge=Identifier@11:9|successor|IntLiteral@13:15 edge=Identifier@11:9|successor|IntLiteral@15:15 edge=Identifier@11:9|successor|IntLiteral@17:15
      when 0 =>
         R := 10;  -- $ edge=AssignStmt@13:10|successor|CaseStmt@11:4 edge=Identifier@13:10|successor|AssignStmt@13:10 edge=IntLiteral@13:15|successor|Identifier@13:10
      when 1 =>
         R := 11;  -- $ edge=AssignStmt@15:10|successor|CaseStmt@11:4 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10
      when others =>
         R := 12;  -- $ edge=AssignStmt@17:10|successor|CaseStmt@11:4 edge=Identifier@17:10|successor|AssignStmt@17:10 edge=IntLiteral@17:15|successor|Identifier@17:10
   end case;  -- $ edge=CaseStmt@11:4|successor|Identifier@20:9

   case Id (N) is  -- $ edge=AssocList@20:13|successor|CallExpr@20:9 edge=CallExpr@20:9|exception|exitSubpBody(abnormal)@8:1 edge=CallExpr@20:9|successor|IntLiteral@22:15 edge=Identifier@20:13|successor|ParamAssoc@20:13 edge=Identifier@20:9|successor|Identifier@20:13 edge=ParamAssoc@20:13|successor|AssocList@20:13
      when others =>
         R := 20;  -- $ edge=AssignStmt@22:10|successor|CaseStmt@20:4 edge=Identifier@22:10|successor|AssignStmt@22:10 edge=IntLiteral@22:15|successor|Identifier@22:10
   end case;  -- $ edge=CaseStmt@20:4|successor|exitSubpBody(normal)@8:1
end Case_Stmt;  -- $ edge=enterSubpBody@8:1|successor|Identifier@11:9 edge=exitSubpBody(abnormal)@8:1|successor|exitSubpBody@8:1 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
