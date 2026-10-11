--  Primitive operations and overriding (Subprogram.isPrimitiveOf, overrides).
package Shapes is
   type Shape is tagged null record;
   function Area (S : Shape) return Integer;
   procedure Scale (S : in out Shape; By : Integer);
   procedure Log (S : Shape);

   --  not primitive: Integer is not tagged
   function Twice (X : Integer) return Integer;

   type Square is new Shape with null record;
   overriding function Area (S : Square) return Integer;
   --  same name, different number of parameters: not an override
   procedure Scale (S : in out Square; By, Extra : Integer);

   type Cube is new Square with null record;
   overriding function Area (S : Cube) return Integer;
   overriding procedure Log (S : Cube);

   type Circle is new Shape with null record;
   overriding function Area (S : Circle) return Integer;
end Shapes;
