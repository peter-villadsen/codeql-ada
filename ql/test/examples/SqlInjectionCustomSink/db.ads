package Db is
   procedure Run (Sql : String);
   --  Runs an SQL statement.

   function Quote (S : String) return String;
   --  S as an SQL string literal, with its quotes doubled.
end Db;
