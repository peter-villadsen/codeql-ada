with Pkg_A, Pkg_B;
with Ada.Text_IO;         --  BAD, runtime package never used (D-026)
with Ada.Command_Line;    --  fine, used below
with GNAT.OS_Lib;         --  fine, used below through the renaming
procedure Test is
   N : Natural := Ada.Command_Line.Argument_Count;
   C : Character := GNAT.OS_Lib.Directory_Separator;
begin
   Pkg_A.Do_Something;
end Test;
