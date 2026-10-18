--  CFG conformance: handled statement sequences and exception handlers.
--  The first block has a "when others" handler, so a raise inside it cannot
--  escape; the second does not, so a raise escapes to the scope exit. The
--  third nests them: the inner block has no "when others", so its raise
--  escapes into the *enclosing* handler rather than out of the scope.
--  See docs/cfg-design.md, "Exceptions".
procedure Exceptions (N : in out Integer) is
   procedure P is null;
begin
   begin
      P;  -- $ edge=CallStmt@11:7|exception|ExceptionHandler@14:7 edge=CallStmt@11:7|successor|after:CallStmt@11:7 edge=Identifier@11:7|successor|CallStmt@11:7 edge=after:CallStmt@11:7|successor|before:RaiseStmt@12:7 edge=before:CallStmt@11:7|successor|Identifier@11:7
      raise Constraint_Error;  -- $ edge=Identifier@12:13|successor|RaiseStmt@12:7 edge=RaiseStmt@12:7|exception|ExceptionHandler@14:7 edge=StmtList@11:7|successor|before:CallStmt@11:7 edge=before:RaiseStmt@12:7|successor|Identifier@12:13
   exception
      when Constraint_Error =>
         N := 1;  -- $ edge=AssignStmt@15:10|successor|after:AssignStmt@15:10 edge=ExceptionHandler@14:7|match|after-true:ExceptionHandler@14:7 edge=ExceptionHandler@14:7|no-match|after-false:ExceptionHandler@14:7 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10 edge=StmtList@15:10|successor|before:AssignStmt@15:10 edge=after-false:ExceptionHandler@14:7|successor|ExceptionHandler@16:7 edge=after-true:ExceptionHandler@14:7|successor|StmtList@15:10 edge=after:AssignStmt@15:10|successor|after:StmtList@15:10 edge=after:StmtList@15:10|successor|after:HandledStmts@10:9 edge=before:AssignStmt@15:10|successor|IntLiteral@15:15
      when others =>
         N := 2;  -- $ edge=AssignStmt@17:10|successor|after:AssignStmt@17:10 edge=ExceptionHandler@16:7|match|after-true:ExceptionHandler@16:7 edge=Identifier@17:10|successor|AssignStmt@17:10 edge=IntLiteral@17:15|successor|Identifier@17:10 edge=StmtList@17:10|successor|before:AssignStmt@17:10 edge=after-true:ExceptionHandler@16:7|successor|StmtList@17:10 edge=after:AssignStmt@17:10|successor|after:StmtList@17:10 edge=after:StmtList@17:10|successor|after:HandledStmts@10:9 edge=before:AssignStmt@17:10|successor|IntLiteral@17:15
   end;  -- $ edge=BeginBlock@10:4|successor|HandledStmts@10:9 edge=HandledStmts@10:9|successor|StmtList@11:7 edge=after:BeginBlock@10:4|successor|BeginBlock@20:4 edge=after:HandledStmts@10:9|successor|after:BeginBlock@10:4

   begin
      P;  -- $ edge=CallStmt@21:7|exception|ExceptionHandler@23:7 edge=CallStmt@21:7|successor|after:CallStmt@21:7 edge=Identifier@21:7|successor|CallStmt@21:7 edge=StmtList@21:7|successor|before:CallStmt@21:7 edge=after:CallStmt@21:7|successor|after:StmtList@21:7 edge=after:StmtList@21:7|successor|after:HandledStmts@20:9 edge=before:CallStmt@21:7|successor|Identifier@21:7
   exception
      when Constraint_Error =>
         N := 3;  -- $ edge=AssignStmt@24:10|successor|after:AssignStmt@24:10 edge=ExceptionHandler@23:7|match|after-true:ExceptionHandler@23:7 edge=ExceptionHandler@23:7|no-match|after-false:ExceptionHandler@23:7 edge=Identifier@24:10|successor|AssignStmt@24:10 edge=IntLiteral@24:15|successor|Identifier@24:10 edge=StmtList@24:10|successor|before:AssignStmt@24:10 edge=after-false:ExceptionHandler@23:7|exception|exitSubpBody(abnormal)@7:1 edge=after-true:ExceptionHandler@23:7|successor|StmtList@24:10 edge=after:AssignStmt@24:10|successor|after:StmtList@24:10 edge=after:StmtList@24:10|successor|after:HandledStmts@20:9 edge=before:AssignStmt@24:10|successor|IntLiteral@24:15
   end;  -- $ edge=BeginBlock@20:4|successor|HandledStmts@20:9 edge=HandledStmts@20:9|successor|StmtList@21:7 edge=after:BeginBlock@20:4|successor|BeginBlock@27:4 edge=after:HandledStmts@20:9|successor|after:BeginBlock@20:4

   begin
      begin
         P;  -- $ edge=CallStmt@29:10|exception|ExceptionHandler@31:10 edge=CallStmt@29:10|successor|after:CallStmt@29:10 edge=Identifier@29:10|successor|CallStmt@29:10 edge=StmtList@29:10|successor|before:CallStmt@29:10 edge=after:CallStmt@29:10|successor|after:StmtList@29:10 edge=after:StmtList@29:10|successor|after:HandledStmts@28:12 edge=before:CallStmt@29:10|successor|Identifier@29:10
      exception
         when Program_Error =>
            N := 5;  -- $ edge=AssignStmt@32:13|successor|after:AssignStmt@32:13 edge=ExceptionHandler@31:10|match|after-true:ExceptionHandler@31:10 edge=ExceptionHandler@31:10|no-match|after-false:ExceptionHandler@31:10 edge=Identifier@32:13|successor|AssignStmt@32:13 edge=IntLiteral@32:18|successor|Identifier@32:13 edge=StmtList@32:13|successor|before:AssignStmt@32:13 edge=after-false:ExceptionHandler@31:10|exception|ExceptionHandler@35:7 edge=after-true:ExceptionHandler@31:10|successor|StmtList@32:13 edge=after:AssignStmt@32:13|successor|after:StmtList@32:13 edge=after:StmtList@32:13|successor|after:HandledStmts@28:12 edge=before:AssignStmt@32:13|successor|IntLiteral@32:18
      end;  -- $ edge=BeginBlock@28:7|successor|HandledStmts@28:12 edge=HandledStmts@28:12|successor|StmtList@29:10 edge=StmtList@28:7|successor|BeginBlock@28:7 edge=after:BeginBlock@28:7|successor|after:StmtList@28:7 edge=after:HandledStmts@28:12|successor|after:BeginBlock@28:7 edge=after:StmtList@28:7|successor|after:HandledStmts@27:9
   exception
      when others =>
         N := 6;  -- $ edge=AssignStmt@36:10|successor|after:AssignStmt@36:10 edge=ExceptionHandler@35:7|match|after-true:ExceptionHandler@35:7 edge=Identifier@36:10|successor|AssignStmt@36:10 edge=IntLiteral@36:15|successor|Identifier@36:10 edge=StmtList@36:10|successor|before:AssignStmt@36:10 edge=after-true:ExceptionHandler@35:7|successor|StmtList@36:10 edge=after:AssignStmt@36:10|successor|after:StmtList@36:10 edge=after:StmtList@36:10|successor|after:HandledStmts@27:9 edge=before:AssignStmt@36:10|successor|IntLiteral@36:15
   end;  -- $ edge=BeginBlock@27:4|successor|HandledStmts@27:9 edge=HandledStmts@27:9|successor|StmtList@28:7 edge=after:BeginBlock@27:4|successor|before:AssignStmt@39:4 edge=after:HandledStmts@27:9|successor|after:BeginBlock@27:4

   N := 4;  -- $ edge=AssignStmt@39:4|successor|after:AssignStmt@39:4 edge=Identifier@39:4|successor|AssignStmt@39:4 edge=IntLiteral@39:9|successor|Identifier@39:4 edge=StmtList@10:4|successor|BeginBlock@10:4 edge=after:AssignStmt@39:4|successor|after:StmtList@10:4 edge=after:StmtList@10:4|successor|after:HandledStmts@9:6 edge=before:AssignStmt@39:4|successor|IntLiteral@39:9
end Exceptions;  -- $ edge=HandledStmts@9:6|successor|StmtList@10:4 edge=after:HandledStmts@9:6|successor|exitSubpBody(normal)@7:1 edge=enterSubpBody@7:1|successor|HandledStmts@9:6 edge=exitSubpBody(abnormal)@7:1|successor|exitSubpBody@7:1 edge=exitSubpBody(normal)@7:1|successor|exitSubpBody@7:1
