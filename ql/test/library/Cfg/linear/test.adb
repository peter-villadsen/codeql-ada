--  CFG conformance: straight-line code.
--  Covers StmtList sequencing, NullStmt, AssignStmt (RHS before LHS),
--  CallStmt/CallExpr with their conservative raise edges, multi-argument
--  evaluation order, and the library's default expression evaluation.
--  See docs/cfg-design.md, "Linear code".
--
--  Log is a null procedure declaration, not a body, so it contributes no
--  scope of its own; Total has no initialiser, so nothing elaborates.
procedure Linear (N : Integer) is
   procedure Log (X, Y : Integer) is null;
   Total : Integer;
begin
   null;  -- $ edge=NullStmt@13:4|successor|before:AssignStmt@14:4
   Total := N + 1;  -- $ edge=AssignStmt@14:4|successor|after:AssignStmt@14:4 edge=BinOp@14:13|successor|after:BinOp@14:13 edge=Identifier@14:13|successor|IntLiteral@14:17 edge=Identifier@14:4|successor|AssignStmt@14:4 edge=IntLiteral@14:17|successor|BinOp@14:13 edge=after:AssignStmt@14:4|successor|before:CallStmt@15:4 edge=after:BinOp@14:13|successor|Identifier@14:4 edge=before:AssignStmt@14:4|successor|before:BinOp@14:13 edge=before:BinOp@14:13|successor|Identifier@14:13
   Log (Total, N);  -- $ edge=AssocList@15:9|successor|after:AssocList@15:9 edge=CallExpr@15:4|exception|exitSubpBody(abnormal)@9:1 edge=CallExpr@15:4|successor|after:CallExpr@15:4 edge=CallStmt@15:4|exception|exitSubpBody(abnormal)@9:1 edge=CallStmt@15:4|successor|after:CallStmt@15:4 edge=Identifier@15:16|successor|ParamAssoc@15:16 edge=Identifier@15:4|successor|before:AssocList@15:9 edge=Identifier@15:9|successor|ParamAssoc@15:9 edge=ParamAssoc@15:16|successor|after:ParamAssoc@15:16 edge=ParamAssoc@15:9|successor|after:ParamAssoc@15:9 edge=StmtList@13:4|successor|NullStmt@13:4 edge=after:AssocList@15:9|successor|CallExpr@15:4 edge=after:CallExpr@15:4|successor|CallStmt@15:4 edge=after:CallStmt@15:4|successor|after:StmtList@13:4 edge=after:ParamAssoc@15:16|successor|AssocList@15:9 edge=after:ParamAssoc@15:9|successor|before:ParamAssoc@15:16 edge=after:StmtList@13:4|successor|after:HandledStmts@12:6 edge=before:AssocList@15:9|successor|before:ParamAssoc@15:9 edge=before:CallExpr@15:4|successor|Identifier@15:4 edge=before:CallStmt@15:4|successor|before:CallExpr@15:4 edge=before:ParamAssoc@15:16|successor|Identifier@15:16 edge=before:ParamAssoc@15:9|successor|Identifier@15:9
end Linear;  -- $ edge=HandledStmts@12:6|successor|StmtList@13:4 edge=after:HandledStmts@12:6|successor|exitSubpBody(normal)@9:1 edge=enterSubpBody@9:1|successor|HandledStmts@12:6 edge=exitSubpBody(abnormal)@9:1|successor|exitSubpBody@9:1 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
