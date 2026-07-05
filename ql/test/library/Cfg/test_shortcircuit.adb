procedure Test_Shortcircuit (A, B, C : Boolean; N : Integer) is
   R : Integer := 0;
begin
   --  nested `and then` / `or else` in a condition
   if A and then (B or else C) then
      R := 1;
   end if;

   --  an `if` expression in an assignment
   R := (if A then 10 elsif B then 20 else 30);
end Test_Shortcircuit;
