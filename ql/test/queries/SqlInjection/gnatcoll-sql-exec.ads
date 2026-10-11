package GNATCOLL.SQL.Exec is
   type Database_Connection is private;
   type Forward_Cursor is private;
   type SQL_Parameters is array (Positive range <>) of Integer;
   No_Parameters : constant SQL_Parameters (1 .. 0) := (others => 0);

   procedure Execute
     (Connection : Database_Connection; Query : String;
      Params : SQL_Parameters := No_Parameters);
   procedure Execute
     (Connection : Database_Connection; Query : SQL_Query;
      Params : SQL_Parameters := No_Parameters);
   procedure Fetch
     (Result : out Forward_Cursor; Connection : Database_Connection; Query : String;
      Params : SQL_Parameters := No_Parameters);
private
   type Database_Connection is null record;
   type Forward_Cursor is null record;
end GNATCOLL.SQL.Exec;
