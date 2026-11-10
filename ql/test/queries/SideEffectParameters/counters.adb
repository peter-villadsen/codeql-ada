package body Counters is
   Id, Seq, Seed : Integer := 0;

   function Next_Id return Integer is
   begin
      Id := Id + 1;
      return Id;
   end Next_Id;

   function Next_Seq return Integer is
   begin
      Seq := Seq + 1;
      return Seq;
   end Next_Seq;

   function Random return Integer is
   begin
      Seed := (Seed * 7 + 3) mod 101;
      return Seed;
   end Random;

   function Pure_Value (X : Integer) return Integer is (X * 2);

   procedure Record_Pair (A, B : Integer) is null;
end Counters;
