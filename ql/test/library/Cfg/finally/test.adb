--  CFG conformance: a GNAT `finally` part runs after the protected statements or a
--  handler finish normally, then the sequence completes. In v1 a return, exit, goto
--  or escaping raise leaves without running it.
--  See docs/cfg-design.md, "Finally parts".
pragma Extensions_Allowed (All_Extensions);
procedure Test is
   procedure P is null;
   X : Integer := 0;  -- $ edge=IntLiteral@8:19|successor|HandledStmts@9:6
begin
   begin
      P;  -- $ edge=CallStmt@11:7|exception|ExceptionHandler@14:7 edge=CallStmt@11:7|successor|after:CallStmt@11:7 edge=Identifier@11:7|successor|CallStmt@11:7 edge=after:CallStmt@11:7|successor|before:AssignStmt@12:7 edge=before:CallStmt@11:7|successor|Identifier@11:7
      X := 1;  -- $ edge=AssignStmt@12:7|successor|after:AssignStmt@12:7 edge=Identifier@12:7|successor|AssignStmt@12:7 edge=IntLiteral@12:12|successor|Identifier@12:7 edge=StmtList@11:7|successor|before:CallStmt@11:7 edge=after:AssignStmt@12:7|successor|after:StmtList@11:7 edge=after:StmtList@11:7|successor|StmtList@17:7 edge=before:AssignStmt@12:7|successor|IntLiteral@12:12
   exception
      when others =>
         X := 2;  -- $ edge=AssignStmt@15:10|successor|after:AssignStmt@15:10 edge=ExceptionHandler@14:7|match|after-true:ExceptionHandler@14:7 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10 edge=StmtList@15:10|successor|before:AssignStmt@15:10 edge=after-true:ExceptionHandler@14:7|successor|StmtList@15:10 edge=after:AssignStmt@15:10|successor|after:StmtList@15:10 edge=after:StmtList@15:10|successor|StmtList@17:7 edge=before:AssignStmt@15:10|successor|IntLiteral@15:15
   finally
      X := 3;  -- $ edge=AssignStmt@17:7|successor|after:AssignStmt@17:7 edge=Identifier@17:7|successor|AssignStmt@17:7 edge=IntLiteral@17:12|successor|Identifier@17:7 edge=StmtList@17:7|successor|before:AssignStmt@17:7 edge=after:AssignStmt@17:7|successor|after:StmtList@17:7 edge=after:StmtList@17:7|successor|after:HandledStmts@10:9 edge=before:AssignStmt@17:7|successor|IntLiteral@17:12
   end;  -- $ edge=BeginBlock@10:4|successor|HandledStmts@10:9 edge=HandledStmts@10:9|successor|StmtList@11:7 edge=after:BeginBlock@10:4|successor|before:AssignStmt@19:4 edge=after:HandledStmts@10:9|successor|after:BeginBlock@10:4
   X := 4;  -- $ edge=AssignStmt@19:4|successor|after:AssignStmt@19:4 edge=Identifier@19:4|successor|AssignStmt@19:4 edge=IntLiteral@19:9|successor|Identifier@19:4 edge=StmtList@10:4|successor|BeginBlock@10:4 edge=after:AssignStmt@19:4|successor|after:StmtList@10:4 edge=after:StmtList@10:4|successor|after:HandledStmts@9:6 edge=before:AssignStmt@19:4|successor|IntLiteral@19:9
end Test;  -- $ edge=HandledStmts@9:6|successor|StmtList@10:4 edge=after:HandledStmts@9:6|successor|exitSubpBody(normal)@6:1 edge=enterSubpBody@6:1|successor|IntLiteral@8:19 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
