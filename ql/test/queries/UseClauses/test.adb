with Ada.Text_IO; use Ada.Text_IO;                  --  BAD: global
with Ada.Strings.Unbounded;
use type Ada.Strings.Unbounded.Unbounded_String;   --  type_global
procedure Test is
   use Ada.Strings.Unbounded;                      --  local
   use all type Ada.Text_IO.File_Mode;             --  all_type_local
   S : Unbounded_String := To_Unbounded_String ("x");
begin
   if S = S then
      Put_Line (To_String (S));
   end if;
end Test;
