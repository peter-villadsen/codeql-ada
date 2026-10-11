with Ada.Directories;
with Ada.Text_IO;
with Ada.Streams; use Ada.Streams;
with GNAT.Sockets; use GNAT.Sockets;
with AWS.Status;

procedure Test is
   procedure Open_Named (Name : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Name);  --  BAD: network data
      Ada.Text_IO.Close (F);
   end Open_Named;

   function Callback (Request : AWS.Status.Data) return Boolean is
      P : constant String := AWS.Status.Parameter (Request, "file");
   begin
      Ada.Directories.Delete_File (Ada.Directories.Compose ("/srv", P));  --  BAD: request data
      Ada.Directories.Delete_File
        (Ada.Directories.Compose ("/srv", Ada.Directories.Simple_Name (P)));  --  fine: no directory part
      Ada.Directories.Copy_File (Source_Name => "a.txt", Target_Name => AWS.Status.URI (Request));  --  BAD
      return True;
   end Callback;

   Sock : Socket_Type;
   Buf  : Stream_Element_Array (1 .. 16);
   Last : Stream_Element_Offset;
begin
   Open_Named (String'Input (Stream (Sock)));
   Open_Named (Ada.Directories.Simple_Name (String'Input (Stream (Sock))));
   Ada.Text_IO.Put_Line (String'Input (Stream (Sock)));  --  fine: not a path
   Receive_Socket (Sock, Buf, Last);
   Open_Named (Stream_Element'Image (Buf (1)));
end Test;
