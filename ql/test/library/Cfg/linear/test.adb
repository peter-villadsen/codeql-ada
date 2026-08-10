--  CFG conformance: straight-line code.
--  Covers StmtList sequencing, NullStmt, AssignStmt (RHS before LHS),
--  CallStmt/CallExpr with their conservative raise edges, and generic
--  post-order expression evaluation. See docs/cfg-design.md, "Linear code".
--
--  Log is a null procedure declaration, not a body, so it contributes no
--  scope of its own; Total has no initialiser, so nothing elaborates.
procedure Linear (N : Integer) is
   procedure Log (X : Integer) is null;
   Total : Integer;
begin
   null;  -- $ edge=NullStmt@12:4|successor|Identifier@13:13
   Total := N + 1;  -- $ edge=AssignStmt@13:4|successor|Identifier@14:4 edge=BinOp@13:13|successor|Identifier@13:4 edge=Identifier@13:13|successor|IntLiteral@13:17 edge=Identifier@13:4|successor|AssignStmt@13:4 edge=IntLiteral@13:17|successor|BinOp@13:13
   Log (Total);  -- $ edge=AssocList@14:9|successor|CallExpr@14:4 edge=CallExpr@14:4|exception|exitSubpBody(abnormal)@8:1 edge=CallExpr@14:4|successor|CallStmt@14:4 edge=CallStmt@14:4|exception|exitSubpBody(abnormal)@8:1 edge=CallStmt@14:4|successor|exitSubpBody(normal)@8:1 edge=Identifier@14:4|successor|Identifier@14:9 edge=Identifier@14:9|successor|ParamAssoc@14:9 edge=ParamAssoc@14:9|successor|AssocList@14:9
end Linear;  -- $ edge=enterSubpBody@8:1|successor|NullStmt@12:4 edge=exitSubpBody(abnormal)@8:1|successor|exitSubpBody@8:1 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
