with Ada.Text_IO;

procedure Good is
begin
   Ada.Text_IO.Put_Line ("first");
exception
   when Constraint_Error =>      --  GOOD: specific exception
      null;
   when others =>                --  GOOD: does something
      Ada.Text_IO.Put_Line ("unexpected failure");
      raise;
end Good;
