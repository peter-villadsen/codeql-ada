with Ada.Text_IO;

procedure Test (Bail : Boolean) is

   --  BUG: opened, never closed on any path
   procedure Leaks is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
   end Leaks;

   --  fine: always closed
   procedure ClosesAlways is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
      Ada.Text_IO.Close (F);
   end ClosesAlways;

   --  BUG: an early return skips the close on one path
   procedure LeaksOnEarlyReturn (Bail : Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, "output.txt");
      if Bail then
         return;
      end if;
      Ada.Text_IO.Delete (F);
   end LeaksOnEarlyReturn;

   --  BUG: a bare Open under a use clause, never closed
   procedure LeaksViaUse is
      use Ada.Text_IO;
      F : File_Type;
   begin
      Open (F, In_File, "input.txt");
   end LeaksViaUse;

   --  BUG: opened through a package renaming, never closed
   procedure LeaksViaRenaming is
      package TIO renames Ada.Text_IO;
      F : TIO.File_Type;
   begin
      TIO.Open (F, TIO.In_File, "input.txt");
   end LeaksViaRenaming;

   --  fine: closed through a subprogram renaming
   procedure ClosesViaSubpRenaming is
      procedure Shut (File : in out Ada.Text_IO.File_Type) renames Ada.Text_IO.Close;
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
      Shut (F);
   end ClosesViaSubpRenaming;
begin
   Leaks;
   ClosesAlways;
   LeaksOnEarlyReturn (Bail);
   LeaksViaUse;
   LeaksViaRenaming;
   ClosesViaSubpRenaming;
end Test;
