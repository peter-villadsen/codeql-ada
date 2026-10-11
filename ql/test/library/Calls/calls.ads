--  Call shapes for the Call class (Phase 12).
with Ada.Unchecked_Deallocation;

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

   --  instances of generic subprograms: a call targets the generic
   type Int_Ptr is access Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Ptr);

   generic
   procedure G_Proc (Item : Integer);
   procedure Inst is new G_Proc;

   Ptr : Int_Ptr;

   procedure Main;
end Calls;
