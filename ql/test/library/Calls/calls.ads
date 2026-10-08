--  Call shapes for the Call class (Phase 12).
package Calls is
   procedure P (A : Integer; B : Integer := 0);
   function F (X : Integer) return Integer;
   function G return Integer;
   procedure Q;

   type T is tagged null record;
   procedure Prim (Self : T; V : Integer);
   function "-" (L, R : T) return T;

   --  a renaming that renames the formals too
   procedure R (C : Integer; D : Integer := 0) renames P;

   protected PO is
      procedure Op (V : Integer);
   end PO;

   type Arr is array (1 .. 3) of Integer;

   procedure Main;
end Calls;
