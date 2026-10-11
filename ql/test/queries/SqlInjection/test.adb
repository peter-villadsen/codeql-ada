with GNAT.Sockets; use GNAT.Sockets;
with GNATCOLL.SQL; use GNATCOLL.SQL;
with GNATCOLL.SQL.Exec; use GNATCOLL.SQL.Exec;

procedure Test is
   DB  : Database_Connection;
   Cur : Forward_Cursor;

   procedure Delete_User (Name : String) is
   begin
      Execute (DB, "DELETE FROM users WHERE name = '" & Name & "'");  --  BAD
   end Delete_User;

   Sock : Socket_Type;
   Name : constant String := String'Input (Stream (Sock));
begin
   Delete_User (Name);
   Fetch (Cur, DB, Query => "SELECT * FROM users WHERE name = '" & Name & "'");  --  BAD
   Execute (DB, "DELETE FROM users WHERE id = 1");  --  fine: constant
   Execute (DB, To_Query (Name));  --  fine here: not the String overload
end Test;
