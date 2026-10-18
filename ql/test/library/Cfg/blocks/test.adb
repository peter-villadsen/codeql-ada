--  CFG conformance: block statements.
--  Covers a bare begin/end block, a declare block whose local has an
--  initialiser, and a named block. See docs/cfg-design.md, "Blocks".
--
--  Contrast with the scopes family: a declare block DOES elaborate its object
--  declarations, so the call on the Local initialiser is in the graph. The
--  identical declaration in a subprogram's declarative part is not (C-1).
procedure Blocks (N : in out Integer) is
   function Id (X : Integer) return Integer is (X);  -- $ edge=Identifier@9:49|successor|ParenExpr@9:48 edge=ParenExpr@9:48|successor|after:ParenExpr@9:48 edge=after:ParenExpr@9:48|successor|exitExprFunction(normal)@9:4 edge=before:ParenExpr@9:48|successor|Identifier@9:49 edge=enterExprFunction@9:4|successor|before:ParenExpr@9:48 edge=exitExprFunction(normal)@9:4|successor|exitExprFunction@9:4
begin
   begin
      N := 1;  -- $ edge=AssignStmt@12:7|successor|after:AssignStmt@12:7 edge=Identifier@12:7|successor|AssignStmt@12:7 edge=IntLiteral@12:12|successor|Identifier@12:7 edge=StmtList@12:7|successor|before:AssignStmt@12:7 edge=after:AssignStmt@12:7|successor|after:StmtList@12:7 edge=after:StmtList@12:7|successor|after:HandledStmts@11:9 edge=before:AssignStmt@12:7|successor|IntLiteral@12:12
   end;  -- $ edge=BeginBlock@11:4|successor|HandledStmts@11:9 edge=HandledStmts@11:9|successor|StmtList@12:7 edge=after:BeginBlock@11:4|successor|DeclBlock@15:4 edge=after:HandledStmts@11:9|successor|after:BeginBlock@11:4

   declare
      Local : Integer := Id (N);  -- $ edge=AssocList@16:30|successor|after:AssocList@16:30 edge=CallExpr@16:26|exception|exitSubpBody(abnormal)@8:1 edge=CallExpr@16:26|successor|after:CallExpr@16:26 edge=Identifier@16:26|successor|before:AssocList@16:30 edge=Identifier@16:30|successor|ParamAssoc@16:30 edge=ParamAssoc@16:30|successor|after:ParamAssoc@16:30 edge=after:AssocList@16:30|successor|CallExpr@16:26 edge=after:CallExpr@16:26|successor|HandledStmts@17:9 edge=after:ParamAssoc@16:30|successor|AssocList@16:30 edge=before:AssocList@16:30|successor|before:ParamAssoc@16:30 edge=before:CallExpr@16:26|successor|Identifier@16:26 edge=before:ParamAssoc@16:30|successor|Identifier@16:30
   begin
      N := Local;  -- $ edge=AssignStmt@18:7|successor|after:AssignStmt@18:7 edge=Identifier@18:12|successor|Identifier@18:7 edge=Identifier@18:7|successor|AssignStmt@18:7 edge=StmtList@18:7|successor|before:AssignStmt@18:7 edge=after:AssignStmt@18:7|successor|after:StmtList@18:7 edge=after:StmtList@18:7|successor|after:HandledStmts@17:9 edge=before:AssignStmt@18:7|successor|Identifier@18:12
   end;  -- $ edge=DeclBlock@15:4|successor|before:CallExpr@16:26 edge=HandledStmts@17:9|successor|StmtList@18:7 edge=after:DeclBlock@15:4|successor|NamedStmt@21:4 edge=after:HandledStmts@17:9|successor|after:DeclBlock@15:4

   Named : declare
      K : constant := 3;
      M : Integer := K;  -- $ edge=Identifier@23:22|successor|HandledStmts@24:9
   begin
      N := M;  -- $ edge=AssignStmt@25:7|successor|after:AssignStmt@25:7 edge=Identifier@25:12|successor|Identifier@25:7 edge=Identifier@25:7|successor|AssignStmt@25:7 edge=StmtList@25:7|successor|before:AssignStmt@25:7 edge=after:AssignStmt@25:7|successor|after:StmtList@25:7 edge=after:StmtList@25:7|successor|after:HandledStmts@24:9 edge=before:AssignStmt@25:7|successor|Identifier@25:12
   end Named;  -- $ edge=DeclBlock@21:12|successor|Identifier@23:22 edge=HandledStmts@24:9|successor|StmtList@25:7 edge=NamedStmt@21:4|successor|DeclBlock@21:12 edge=StmtList@11:4|successor|BeginBlock@11:4 edge=after:DeclBlock@21:12|successor|after:NamedStmt@21:4 edge=after:HandledStmts@24:9|successor|after:DeclBlock@21:12 edge=after:NamedStmt@21:4|successor|after:StmtList@11:4 edge=after:StmtList@11:4|successor|after:HandledStmts@10:6
end Blocks;  -- $ edge=HandledStmts@10:6|successor|StmtList@11:4 edge=after:HandledStmts@10:6|successor|exitSubpBody(normal)@8:1 edge=enterSubpBody@8:1|successor|HandledStmts@10:6 edge=exitSubpBody(abnormal)@8:1|successor|exitSubpBody@8:1 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
