package body Calls is
   procedure P (A : Integer; B : Integer := 0) is null;
   function F (X : Integer) return Integer is (X);
   function G return Integer is (1);
   procedure Q is null;
   procedure Prim (Self : T; V : Integer) is null;
   function "-" (L, R : T) return T is (L);

   protected body PO is
      procedure Op (V : Integer) is
      begin
         null;
      end Op;
   end PO;

   procedure Main is
      Obj : T;
      A   : Arr := (others => 0);
      I   : Integer;

      --  a nested subprogram: its calls have it as caller, not Main
      procedure Inner is
      begin
         Q;
      end Inner;
   begin
      P (1, 2);            --  positional, a statement
      P (B => 2, A => 1);  --  named, out of order
      P (1);               --  B left to its default
      I := F (G);          --  in an expression; G is a call without parentheses
      Q;                   --  a statement without parentheses
      Obj.Prim (3);        --  prefixed view: Obj is argument 0
      Obj := Obj - Obj;    --  a user-defined operator
      R (4);               --  through a renaming: the target is P
      PO.Op (5);           --  a protected operation
      I := A (2);          --  indexing: not a call
      I := Integer (I);    --  a type conversion: not a call
      Unknown (I);         --  does not resolve: not a call
      Inner;
      Free (Ptr);          --  an instance of Ada.Unchecked_Deallocation
      Inst (Item => 6);    --  an instance of a generic in this package
   end Main;

   procedure G_Proc (Item : Integer) is null;
end Calls;
