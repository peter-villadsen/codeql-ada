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
      P;  -- $ edge=CallStmt@11:7|exception|IntLiteral@15:15 edge=CallStmt@11:7|exception|IntLiteral@17:15 edge=CallStmt@11:7|successor|Identifier@12:13 edge=Identifier@11:7|successor|CallStmt@11:7
      raise Constraint_Error;  -- $ edge=Identifier@12:13|successor|RaiseStmt@12:7 edge=RaiseStmt@12:7|exception|IntLiteral@15:15 edge=RaiseStmt@12:7|exception|IntLiteral@17:15
   exception
      when Constraint_Error =>
         N := 1;  -- $ edge=AssignStmt@15:10|successor|Identifier@21:7 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10
      when others =>
         N := 2;  -- $ edge=AssignStmt@17:10|successor|Identifier@21:7 edge=Identifier@17:10|successor|AssignStmt@17:10 edge=IntLiteral@17:15|successor|Identifier@17:10
   end;

   begin
      P;  -- $ edge=CallStmt@21:7|exception|IntLiteral@24:15 edge=CallStmt@21:7|exception|exitSubpBody(abnormal)@7:1 edge=CallStmt@21:7|successor|Identifier@29:10 edge=Identifier@21:7|successor|CallStmt@21:7
   exception
      when Constraint_Error =>
         N := 3;  -- $ edge=AssignStmt@24:10|successor|Identifier@29:10 edge=Identifier@24:10|successor|AssignStmt@24:10 edge=IntLiteral@24:15|successor|Identifier@24:10
   end;

   begin
      begin
         P;  -- $ edge=CallStmt@29:10|exception|IntLiteral@32:18 edge=CallStmt@29:10|exception|IntLiteral@36:15 edge=CallStmt@29:10|successor|IntLiteral@39:9 edge=Identifier@29:10|successor|CallStmt@29:10
      exception
         when Program_Error =>
            N := 5;  -- $ edge=AssignStmt@32:13|successor|IntLiteral@39:9 edge=Identifier@32:13|successor|AssignStmt@32:13 edge=IntLiteral@32:18|successor|Identifier@32:13
      end;
   exception
      when others =>
         N := 6;  -- $ edge=AssignStmt@36:10|successor|IntLiteral@39:9 edge=Identifier@36:10|successor|AssignStmt@36:10 edge=IntLiteral@36:15|successor|Identifier@36:10
   end;

   N := 4;  -- $ edge=AssignStmt@39:4|successor|exitSubpBody(normal)@7:1 edge=Identifier@39:4|successor|AssignStmt@39:4 edge=IntLiteral@39:9|successor|Identifier@39:4
end Exceptions;  -- $ edge=enterSubpBody@7:1|successor|Identifier@11:7 edge=exitSubpBody(abnormal)@7:1|successor|exitSubpBody@7:1 edge=exitSubpBody(normal)@7:1|successor|exitSubpBody@7:1
