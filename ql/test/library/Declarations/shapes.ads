--  Declaration shapes for Type, Component, Variable and Package (Phase 12).
package Shapes is
   type Color is (Red, Green, Blue);
   type Point is record
      X, Y : Integer := 0;
   end record;
   type Shape is tagged record
      Origin : Point;
   end record;
   type Circle is new Shape with record
      Radius : Natural;
   end record;
   type Vector is array (1 .. 3) of Integer;
   type Point_Access is access Point;
   subtype Small is Integer range 0 .. 9;
   type Handle is private;

   Default_Color : constant Color := Red;
   Count         : Integer;

   function Area (C : Circle) return Integer;
private
   type Handle is new Integer;
end Shapes;
