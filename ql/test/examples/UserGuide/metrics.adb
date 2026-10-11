procedure Metrics is
   function Fact (N : Natural) return Natural is
   begin
      if N = 0 then
         return 1;
      else
         return N * Fact (N - 1);
      end if;
   end Fact;

   procedure Ping (N : Natural);

   procedure Pong (N : Natural) is
   begin
      if N > 0 then
         Ping (N - 1);
      end if;
   end Pong;

   procedure Ping (N : Natural) is
   begin
      Pong (N);
   end Ping;

   function Score (Text : String) return Natural is
      Total : Natural := 0;
   begin
      for C of Text loop
         case C is
            when 'a' .. 'z' => Total := Total + 1;
            when '0' .. '9' => Total := Total + 2;
            when others     => null;
         end case;
         exit when Total > 100 and then C = '.';
      end loop;
      return Total;
   exception
      when Constraint_Error =>
         return 0;
   end Score;
begin
   Pong (Fact (3) + Score ("abc"));
end Metrics;
