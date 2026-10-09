with Ada.Text_IO;

package body Logs is
   Log : Ada.Text_IO.File_Type;

   procedure Open_Log (File_Name : String) is
   begin
      Ada.Text_IO.Open (Log, Ada.Text_IO.Append_File, File_Name);  --  BAD
   end Open_Log;

   procedure Reopen (Name : String) is
   begin
      Ada.Text_IO.Open (Log, Ada.Text_IO.Append_File, Name);       --  fine: private
   end Reopen;

   procedure Rotate is
   begin
      Reopen ("current.log");
   end Rotate;
end Logs;
