with Ada.Text_IO;
with Ada.Finalization;
procedure Test is
   type Res is new Ada.Finalization.Controlled with null record;
   F : Float := 1.0;
   B : Boolean := F > 0.0;
begin
   Ada.Text_IO.Put_Line (Integer'Image (1));
   if not B then
      raise Constraint_Error;
   end if;
end Test;
