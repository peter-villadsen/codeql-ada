package Shapes is
   type Shape is tagged null record;
   function Area (S : Shape) return Integer;
   procedure Put (S : Shape; V : Integer);

   type Square is new Shape with null record;
   overriding function Area (S : Square) return Integer;
end Shapes;
