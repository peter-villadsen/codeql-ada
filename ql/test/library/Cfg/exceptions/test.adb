--  CFG conformance: handled statement sequences and exception handlers.
--  The first block has a "when others" handler, so a raise inside it cannot
--  escape; the second does not, so a raise escapes to the scope exit.
--  See docs/cfg-design.md, "Exceptions".
procedure Exceptions (N : in out Integer) is
   procedure P is null;
begin
   begin
      P;  -- $ edge=CallStmt@9:7|exception|IntLiteral@13:15 edge=CallStmt@9:7|exception|IntLiteral@15:15 edge=CallStmt@9:7|successor|Identifier@10:13 edge=Identifier@9:7|successor|CallStmt@9:7
      raise Constraint_Error;  -- $ edge=Identifier@10:13|successor|RaiseStmt@10:7 edge=RaiseStmt@10:7|exception|IntLiteral@13:15 edge=RaiseStmt@10:7|exception|IntLiteral@15:15
   exception
      when Constraint_Error =>
         N := 1;  -- $ edge=AssignStmt@13:10|successor|Identifier@19:7 edge=Identifier@13:10|successor|AssignStmt@13:10 edge=IntLiteral@13:15|successor|Identifier@13:10
      when others =>
         N := 2;  -- $ edge=AssignStmt@15:10|successor|Identifier@19:7 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10
   end;

   begin
      P;  -- $ edge=CallStmt@19:7|exception|IntLiteral@22:15 edge=CallStmt@19:7|exception|exitSubpBody(abnormal)@5:1 edge=CallStmt@19:7|successor|IntLiteral@25:9 edge=Identifier@19:7|successor|CallStmt@19:7
   exception
      when Constraint_Error =>
         N := 3;  -- $ edge=AssignStmt@22:10|successor|IntLiteral@25:9 edge=Identifier@22:10|successor|AssignStmt@22:10 edge=IntLiteral@22:15|successor|Identifier@22:10
   end;

   N := 4;  -- $ edge=AssignStmt@25:4|successor|exitSubpBody(normal)@5:1 edge=Identifier@25:4|successor|AssignStmt@25:4 edge=IntLiteral@25:9|successor|Identifier@25:4
end Exceptions;  -- $ edge=enterSubpBody@5:1|successor|Identifier@9:7 edge=exitSubpBody(abnormal)@5:1|successor|exitSubpBody@5:1 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
