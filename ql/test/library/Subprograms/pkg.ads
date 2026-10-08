--  Subprogram shapes for the Subprogram and Parameter classes (Phase 12).
package Pkg is
   --  spec in the .ads, body in the .adb; grouped parameters; all modes
   procedure Spec_And_Body (A, B : in Integer; C : out Integer; D : in out Integer);

   --  completed by an expression function; a default value
   function Fn (X : Integer := 0) return Integer;

   --  body is separate (stub in the .adb, subunit in pkg-separate_body.adb)
   procedure Separate_Body (S : String);

   --  no body anywhere
   procedure Null_Proc (N : Integer) is null;

   procedure Imported (I : Integer);
   pragma Import (C, Imported, "imported");

   --  a renaming is a subprogram of its own
   procedure Renamed (Q : String) renames Separate_Body;

   --  a generic subprogram is a Subprogram; its instance Inst (pkg.adb) is not
   --  in v1 (docs/phase12-plan.md)
   generic
      type T is private;
   procedure Gen (V : T);

   type Rec is record
      F : Integer;
   end record;

   --  an operator
   function "+" (L, R : Rec) return Rec;
end Pkg;
