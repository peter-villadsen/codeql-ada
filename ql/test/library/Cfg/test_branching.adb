procedure Test_Branching (N : Integer; B : Boolean) is
   Total : Integer := 0;
begin
   --  if / elsif / else
   if N > 0 then
      Total := 1;
   elsif N < 0 then
      Total := 2;
   else
      Total := 3;
   end if;

   --  case with three alternatives
   case N is
      when 0 =>
         Total := 10;
      when 1 =>
         Total := 11;
      when others =>
         Total := 12;
   end case;

   --  plain loop with conditional exit
   loop
      Total := Total + 1;
      exit when Total > 100;
   end loop;

   --  named outer loop exited from an inner loop
   Outer : loop
      Inner : loop
         exit Outer when B;
         exit Inner;
      end loop Inner;
   end loop Outer;

   --  while loop
   while Total > 0 loop
      Total := Total - 1;
   end loop;

   --  for loop
   for I in 1 .. 10 loop
      Total := Total + I;
   end loop;

   --  goto backward and forward
   <<Again>>
   Total := Total + 1;
   if Total < 5 then
      goto Again;
   end if;
   goto Done;
   Total := 999;
   <<Done>>

   --  declare block with an initialized local
   declare
      Local : Integer := Total * 2;
   begin
      Total := Local;
   end;
end Test_Branching;
