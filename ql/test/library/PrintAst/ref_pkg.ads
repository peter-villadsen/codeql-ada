package Ref_Pkg is
   type Point is record
      X, Y : Integer := 0;
   end record;
   type Color is (Red, Green, Blue);
   subtype Small is Integer range 0 .. 9;
   type Int_Array is array (Positive range <>) of Integer;
   type Point_Access is access all Point;
   type Shape is tagged record
      Id : Integer;
   end record;
   procedure Move (S : in out Shape; By : Integer);
   function Area (S : Shape) return Integer;
end Ref_Pkg;
