procedure Test is
   type Color is (Red, Green, Blue);
   for Color use (1, 2, 4);                                   --  enumeration_representation
   type Rec (D : Integer) is record
      X, Y : Integer;
   end record;
   type Arr is array (1 .. 3) of Integer;
   procedure Box (X, Y, W, H : Integer) is null;
   procedure Mix (X : Integer; C : Color; Y : Integer) is null;
   R : Rec (3) := (3, 1, 2);                                  --  discriminant; record_aggregate
   A : Arr := (1, 2, 3);                                      --  array_aggregate
   pragma Assert (True, "message");                           --  pragma
begin
   Box (1, 2, 3, 4);                                          --  BAD: 4 Integers by position
   Box (X => 1, Y => 2, W => 3, H => 4);                      --  fine: named
   Box (1, 2, 3, H => 4);                                     --  fine: 3 by position
   Mix (1, Red, 2);                                           --  2 Integers by position
end Test;
