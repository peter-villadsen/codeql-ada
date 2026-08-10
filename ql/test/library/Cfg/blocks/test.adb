--  CFG conformance: block statements.
--  Covers a bare begin/end block, a declare block whose local has an
--  initialiser, and a named block. See docs/cfg-design.md, "Blocks".
--
--  Contrast with the scopes family: a declare block DOES elaborate its object
--  declarations, so the call on the Local initialiser is in the graph. The
--  identical declaration in a subprogram's declarative part is not (C-1).
procedure Blocks (N : in out Integer) is
   function Id (X : Integer) return Integer is (X);  -- $ edge=Identifier@9:49|successor|ParenExpr@9:48 edge=ParenExpr@9:48|successor|exitExprFunction(normal)@9:4 edge=enterExprFunction@9:4|successor|Identifier@9:49 edge=exitExprFunction(normal)@9:4|successor|exitExprFunction@9:4
begin
   begin
      N := 1;  -- $ edge=AssignStmt@12:7|successor|Identifier@16:26 edge=Identifier@12:7|successor|AssignStmt@12:7 edge=IntLiteral@12:12|successor|Identifier@12:7
   end;

   declare
      Local : Integer := Id (N);  -- $ edge=AssocList@16:30|successor|CallExpr@16:26 edge=CallExpr@16:26|exception|exitSubpBody(abnormal)@8:1 edge=CallExpr@16:26|successor|Identifier@18:12 edge=Identifier@16:26|successor|Identifier@16:30 edge=Identifier@16:30|successor|ParamAssoc@16:30 edge=ParamAssoc@16:30|successor|AssocList@16:30
   begin
      N := Local;  -- $ edge=AssignStmt@18:7|successor|Identifier@23:22 edge=Identifier@18:12|successor|Identifier@18:7 edge=Identifier@18:7|successor|AssignStmt@18:7
   end;

   Named : declare
      K : constant := 3;
      M : Integer := K;  -- $ edge=Identifier@23:22|successor|Identifier@25:12
   begin
      N := M;  -- $ edge=AssignStmt@25:7|successor|exitSubpBody(normal)@8:1 edge=Identifier@25:12|successor|Identifier@25:7 edge=Identifier@25:7|successor|AssignStmt@25:7
   end Named;
end Blocks;  -- $ edge=enterSubpBody@8:1|successor|IntLiteral@12:12 edge=exitSubpBody(abnormal)@8:1|successor|exitSubpBody@8:1 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
