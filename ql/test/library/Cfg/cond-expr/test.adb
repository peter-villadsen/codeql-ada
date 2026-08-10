--  CFG conformance: conditional expressions.
--  Covers an if expression with an elsif part and a case expression. Both
--  branch like their statement forms but converge on a value.
--  See docs/cfg-design.md, "Conditional expressions".
procedure Cond_Expr (A, B : Boolean; N : in out Integer) is
begin
   N := (if A then 1 elsif B then 2 else 3);  -- $ edge=AssignStmt@7:4|successor|Identifier@9:15 edge=Identifier@7:13|false|Identifier@7:28 edge=Identifier@7:13|true|IntLiteral@7:20 edge=Identifier@7:28|false|IntLiteral@7:42 edge=Identifier@7:28|true|IntLiteral@7:35 edge=Identifier@7:4|successor|AssignStmt@7:4 edge=IfExpr@7:10|successor|ParenExpr@7:9 edge=IntLiteral@7:20|successor|IfExpr@7:10 edge=IntLiteral@7:35|successor|IfExpr@7:10 edge=IntLiteral@7:42|successor|IfExpr@7:10 edge=ParenExpr@7:9|successor|Identifier@7:4

   N := (case N is when 0 => 10, when others => 20);  -- $ edge=AssignStmt@9:4|successor|exitSubpBody(normal)@5:1 edge=CaseExpr@9:10|successor|ParenExpr@9:9 edge=Identifier@9:15|successor|IntLiteral@9:30 edge=Identifier@9:15|successor|IntLiteral@9:49 edge=Identifier@9:4|successor|AssignStmt@9:4 edge=IntLiteral@9:30|successor|CaseExpr@9:10 edge=IntLiteral@9:49|successor|CaseExpr@9:10 edge=ParenExpr@9:9|successor|Identifier@9:4
end Cond_Expr;  -- $ edge=enterSubpBody@5:1|successor|Identifier@7:13 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
