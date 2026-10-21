with Ada.Finalization;
pragma Elaborate_All (Ada.Finalization);
use Ada.Finalization;
with Ada.Text_IO;                                   --  context_clauses_order: with after use
package Shapes is
   type Shape is tagged null record;
   type Circle is new Shape with null record;      --  BAD: a second tagged type
   type Square is new Shape with null record;      --  a third, reported against Shape too
   type Guard is new Controlled with null record;   --  tagged_type_hierarchy: Ada.Finalization
   procedure Draw (S : Shape);
   Max : constant := 10;                            --  declarations_order: a number after a spec
end Shapes;
