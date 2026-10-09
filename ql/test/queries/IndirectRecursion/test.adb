procedure Test is
   procedure P (N : Natural);
   procedure Q (N : Natural);
   procedure R (N : Natural);

   procedure P (N : Natural) is            --  BAD: P -> Q -> R -> P
   begin
      if N > 0 then
         Q (N - 1);
      end if;
   end P;

   procedure Q (N : Natural) is            --  BAD
   begin
      R (N);
   end Q;

   procedure R (N : Natural) is            --  BAD
   begin
      P (N);
   end R;

   function Fact (N : Natural) return Natural is   --  direct only: ada/direct-recursion
     (if N = 0 then 1 else N * Fact (N - 1));

   function Even (N : Natural) return Boolean;
   function Odd (N : Natural) return Boolean is    --  BAD: Odd -> Even -> Odd
     (N /= 0 and then Even (N - 1));
   function Even (N : Natural) return Boolean is   --  BAD
     (N = 0 or else Odd (N - 1));

   procedure Both (N : Natural);
   procedure Helper (N : Natural);
   procedure Both (N : Natural) is         --  BAD: also through Helper
   begin
      if N > 1 then
         Both (N - 1);
         Helper (N - 2);
      end if;
   end Both;

   procedure Helper (N : Natural) is       --  BAD
   begin
      Both (N);
   end Helper;

   procedure Leaf is null;                 --  fine: not recursive
   procedure Calls_Cycle is                --  fine: calls into a cycle, not part of it
   begin
      P (3);
      Leaf;
   end Calls_Cycle;
begin
   Calls_Cycle;
   if Fact (3) = 6 and then Even (4) then
      Both (3);
   end if;
end Test;
