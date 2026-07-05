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
begin
   Leaks;
   ClosesAlways;
   LeaksOnEarlyReturn (Bail);
end Test;
