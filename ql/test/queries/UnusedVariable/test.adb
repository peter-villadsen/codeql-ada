with Ada.Text_IO;
with Missing_Pkg;  --  not available: calls into it do not resolve, nor do their arguments

procedure Test is
   Used   : Integer := 1;
   Spare  : Integer := 2;          --  BAD: never referenced
   Alias  : Integer renames Used;  --  renaming: excluded from the check
   Passed : Integer := 3;          --  used only in an unresolved call: not reported (D-026)
   Guard  : Integer := 4 with Unreferenced;  --  marked by aspect: not reported
   Marked : Integer := 5;          --  marked by pragma: not reported
   pragma Unreferenced (Marked);
   Size   : Integer := 6;          --  BAD: `Used'Size` below is an attribute, not a use
begin
   Ada.Text_IO.Put_Line (Integer'Image (Used));
   Ada.Text_IO.Put_Line (Integer'Image (Used'Size));
   Missing_Pkg.Run (Passed);
end Test;

--  Names GNAT treats as deliberately unused (v0.2.0 precision check): fine.
procedure Junk_Names is
   function Side_Effect return Boolean is (True);
   Dummy  : Integer;
   Ignore : Boolean := Side_Effect;
   Unused_Count : Natural := 0;
begin
   null;
end Junk_Names;
