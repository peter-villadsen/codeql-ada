--  CFG conformance: straight-line code.
--  Covers StmtList sequencing, NullStmt, AssignStmt (RHS before LHS),
--  CallStmt/CallExpr with their conservative raise edges, multi-argument
--  evaluation order, and generic post-order expression evaluation.
--  See docs/cfg-design.md, "Linear code".
--
--  Log is a null procedure declaration, not a body, so it contributes no
--  scope of its own; Total has no initialiser, so nothing elaborates.
procedure Linear (N : Integer) is
   procedure Log (X, Y : Integer) is null;
   Total : Integer;
begin
   null;  -- $ edge=NullStmt@13:4|successor|Identifier@14:13
   Total := N + 1;  -- $ edge=AssignStmt@14:4|successor|Identifier@15:4 edge=BinOp@14:13|successor|Identifier@14:4 edge=Identifier@14:13|successor|IntLiteral@14:17 edge=Identifier@14:4|successor|AssignStmt@14:4 edge=IntLiteral@14:17|successor|BinOp@14:13
   Log (Total, N);  -- $ edge=AssocList@15:9|successor|CallExpr@15:4 edge=CallExpr@15:4|exception|exitSubpBody(abnormal)@9:1 edge=CallExpr@15:4|successor|CallStmt@15:4 edge=CallStmt@15:4|exception|exitSubpBody(abnormal)@9:1 edge=CallStmt@15:4|successor|exitSubpBody(normal)@9:1 edge=Identifier@15:16|successor|ParamAssoc@15:16 edge=Identifier@15:4|successor|Identifier@15:9 edge=Identifier@15:9|successor|ParamAssoc@15:9 edge=ParamAssoc@15:16|successor|AssocList@15:9 edge=ParamAssoc@15:9|successor|Identifier@15:16
end Linear;  -- $ edge=enterSubpBody@9:1|successor|NullStmt@13:4 edge=exitSubpBody(abnormal)@9:1|successor|exitSubpBody@9:1 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
