--  CFG conformance: a GNAT `finally` part runs after the protected statements or a
--  handler finish normally, then the sequence completes. In v1 a return, exit, goto
--  or escaping raise leaves without running it.
--  See docs/cfg-design.md, "Finally parts".
pragma Extensions_Allowed (All_Extensions);
procedure Test is
   procedure P is null;
   X : Integer := 0;  -- $ edge=IntLiteral@8:19|successor|Identifier@11:7
begin
   begin
      P;  -- $ edge=CallStmt@11:7|exception|IntLiteral@15:15 edge=CallStmt@11:7|successor|IntLiteral@12:12 edge=Identifier@11:7|successor|CallStmt@11:7
      X := 1;  -- $ edge=AssignStmt@12:7|successor|IntLiteral@17:12 edge=Identifier@12:7|successor|AssignStmt@12:7 edge=IntLiteral@12:12|successor|Identifier@12:7
   exception
      when others =>
         X := 2;  -- $ edge=AssignStmt@15:10|successor|IntLiteral@17:12 edge=Identifier@15:10|successor|AssignStmt@15:10 edge=IntLiteral@15:15|successor|Identifier@15:10
   finally
      X := 3;  -- $ edge=AssignStmt@17:7|successor|IntLiteral@19:9 edge=Identifier@17:7|successor|AssignStmt@17:7 edge=IntLiteral@17:12|successor|Identifier@17:7
   end;
   X := 4;  -- $ edge=AssignStmt@19:4|successor|exitSubpBody(normal)@6:1 edge=Identifier@19:4|successor|AssignStmt@19:4 edge=IntLiteral@19:9|successor|Identifier@19:4
end Test;  -- $ edge=enterSubpBody@6:1|successor|IntLiteral@8:19 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
