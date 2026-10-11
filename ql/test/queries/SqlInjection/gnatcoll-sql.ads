package GNATCOLL.SQL is
   type SQL_Query is private;
   function To_Query (S : String) return SQL_Query;
private
   type SQL_Query is null record;
end GNATCOLL.SQL;
