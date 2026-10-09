procedure Cycles is
   procedure P (N : Natural);
   procedure Q (N : Natural);
   procedure R (N : Natural);

   procedure P (N : Natural) is          --  P -> Q -> R -> P
   begin
      if N > 0 then
         Q (N - 1);
      end if;
   end P;

   procedure Q (N : Natural) is
   begin
      R (N);
   end Q;

   procedure R (N : Natural) is
   begin
      P (N);
   end R;

   function Fact (N : Natural) return Natural is   --  direct recursion
     (if N = 0 then 1 else N * Fact (N - 1));

   procedure Leaf is null;                 --  not recursive
   procedure Calls_Cycle is                --  calls into the cycle, not part of it
   begin
      P (3);
      Leaf;
   end Calls_Cycle;
begin
   Calls_Cycle;
   if Fact (3) = 6 then
      null;
   end if;
end Cycles;
