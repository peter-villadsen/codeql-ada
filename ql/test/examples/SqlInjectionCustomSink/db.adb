package body Db is
   procedure Run (Sql : String) is
   begin
      null;
   end Run;

   function Quote (S : String) return String is
      Result : String (1 .. 2 * S'Length + 2);
      Last   : Natural := 1;
   begin
      Result (1) := ''';
      for C of S loop
         if C = ''' then
            Last := Last + 1;
            Result (Last) := ''';
         end if;
         Last := Last + 1;
         Result (Last) := C;
      end loop;
      Last := Last + 1;
      Result (Last) := ''';
      return Result (1 .. Last);
   end Quote;
end Db;
