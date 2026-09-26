package body Shapes is
   function Source (Id : Integer) return Integer is (Id);
   procedure Sink (X : Integer) is null;

   function Area (S : Shape) return Integer is (0);

   function Area (S : Square) return Integer is (Source (22));

   --  In prefixed notation the prefix is formal 0, so `V` is formal 1.
   procedure Put (S : Shape; V : Integer) is
   begin
      Sink (V);  -- $ flow=23 flow=28
   end Put;
end Shapes;
