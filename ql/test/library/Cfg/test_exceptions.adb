procedure Test_Exceptions is
   procedure P is null;
   X : Integer := 0;
begin
   --  handled sequence with a specific handler and `when others`
   begin
      P;
      X := 1;
   exception
      when Constraint_Error =>
         X := 2;
      when others =>
         X := 3;
   end;

   --  handler bodies flow to here
   X := 4;

   --  nested handled sequence: inner has no `when others`, so a raise escapes
   --  to the outer `when others`
   begin
      begin
         P;
      exception
         when Program_Error =>
            X := 5;
      end;
   exception
      when others =>
         X := 6;
   end;
end Test_Exceptions;
