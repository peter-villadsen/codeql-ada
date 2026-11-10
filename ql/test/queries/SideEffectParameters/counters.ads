package Counters is
   function Next_Id return Integer;
   function Next_Seq return Integer;
   function Random return Integer;
   function Pure_Value (X : Integer) return Integer;
   procedure Record_Pair (A, B : Integer);
   generic
      First, Second : Integer;
   package Pair is
      Sum : constant Integer := First + Second;
   end Pair;
end Counters;
