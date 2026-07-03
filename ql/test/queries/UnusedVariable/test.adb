with Ada.Text_IO;

procedure Test is
   Used   : Integer := 1;
   Unused : Integer := 2;          --  BAD: never referenced
   Alias  : Integer renames Used;  --  renaming: excluded from the check
begin
   Ada.Text_IO.Put_Line (Integer'Image (Used));
end Test;
