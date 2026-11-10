package Geometry is
   type Length is range 0 .. 1000;
   type Color is (Red, Green);
   function Area (L : Length) return Length;
   procedure Reset;
end Geometry;
