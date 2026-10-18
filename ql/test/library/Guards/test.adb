--  Guards: which statements each guard controls, and with which value.
--  See docs/cfg-design.md and codeql/ada/controlflow/Guards.qll.
procedure Test (A, B : Boolean; N : in out Integer; P : access Integer) is
   procedure S (K : Integer) is null;
   OK : Boolean;
begin
   if A then
      S (1);
   elsif B then
      S (2);
   else
      S (3);
   end if;

   if A and then B then
      S (4);
   end if;

   if not A or else B then
      S (5);
   else
      S (6);
   end if;

   if P /= null then
      S (7);
   end if;

   OK := N > 0;
   if OK then
      S (8);
   end if;

   case N is
      when 1 =>
         S (9);
      when 2 | 3 =>
         S (10);
      when others =>
         S (11);
   end case;

   while N > 0 loop
      S (12);
      N := N - 1;
   end loop;

   loop
      exit when N = 0;
      S (13);
   end loop;

   if N < 10 then
      if N >= 10 then
         S (14);
      end if;
   end if;

   if N > 5 then
      S (15);
   end if;
end Test;
