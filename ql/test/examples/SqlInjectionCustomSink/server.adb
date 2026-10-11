with GNAT.Sockets; use GNAT.Sockets;
with Db;

procedure Server is
   Sock : Socket_Type;

   procedure Delete_User (Name : String) is
   begin
      Db.Run ("DELETE FROM users WHERE name = '" & Name & "'");      --  flagged
   end Delete_User;

   procedure Delete_User_Safely (Name : String) is
   begin
      Db.Run ("DELETE FROM users WHERE name = " & Db.Quote (Name));  --  not flagged
   end Delete_User_Safely;

   Name : constant String := String'Input (Stream (Sock));
begin
   Delete_User (Name);
   Delete_User_Safely (Name);
   Db.Run ("DELETE FROM users WHERE id = 1");                        --  not flagged
end Server;
