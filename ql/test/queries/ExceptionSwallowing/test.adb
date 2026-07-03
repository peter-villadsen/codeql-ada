with Ada.Text_IO;

procedure Test is
begin
   Ada.Text_IO.Put_Line ("first");
exception
   when others =>          --  BAD: swallows everything
      null;
end Test;
