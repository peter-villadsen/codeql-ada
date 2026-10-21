package body Shapes is
   function Area (S : Shape) return Float is (0.0);
   procedure Draw (S : Shape) is null;
   overriding function Area (C : Circle) return Float is (3.14 * C.R * C.R);
   procedure Draw (C : Circle) is null;
   overriding procedure Print (C : Circle) is null;
   procedure Grow (C : in out Circle) is null;
   procedure Shrink (C : in out Circle) is null;
   procedure Draw (B : Ball) is null;
end Shapes;
