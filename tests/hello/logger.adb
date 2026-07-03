with Ada.Text_IO;

procedure Logger is
   procedure Risky is
   begin
      Ada.Text_IO.Put_Line ("about to fail");
      raise Constraint_Error;
   end Risky;
begin
   Risky;
exception
   when others =>
      null;
end Logger;
