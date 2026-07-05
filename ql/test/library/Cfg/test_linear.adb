procedure Test_Linear is
   procedure P (A : Integer; B : Integer) is null;
   function F (X : Integer) return Integer is (X + 1);

   function G (X : Integer) return Integer is
   begin
      return X * 2;
   end G;

   Y : Integer := 0;
   Z : Integer;
begin
   Y := 1;
   P (Y, Y + 1);
   Z := F (Y) + G (Y + 1);
   Y := Z;
end Test_Linear;
