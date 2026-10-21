package Shapes is
   type Shape is tagged null record;
   function Area (S : Shape) return Float;
   procedure Draw (S : Shape);

   type Printable is interface;
   procedure Print (P : Printable) is abstract;

   type Circle is new Shape and Printable with record
      R : Float;
   end record;
   overriding function Area (C : Circle) return Float;   --  fine
   procedure Draw (C : Circle);                           --  BAD: overriding, no indicator
   overriding procedure Print (C : Circle);               --  fine
   procedure Grow (C : in out Circle);                    --  new: not overriding
   not overriding procedure Shrink (C : in out Circle);   --  fine

   type Ball is new Circle with null record;
   procedure Draw (B : Ball);                             --  BAD

   type Count is new Integer;
   subtype Small_Count is Count range 0 .. 10;
   type Tally is new Small_Count;
end Shapes;

package More_Shapes is
   type Base is tagged null record;
   procedure Add (B : in out Base; X : Integer);
   type Derived is new Base with null record;
   function Add (B : Derived; X : Integer) return Derived;   --  fine: a function, new
end More_Shapes;
