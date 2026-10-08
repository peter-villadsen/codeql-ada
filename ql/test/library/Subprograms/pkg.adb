package body Pkg is
   procedure Spec_And_Body (A, B : in Integer; C : out Integer; D : in out Integer) is
   begin
      C := A + B;
      D := D + 1;
   end Spec_And_Body;

   function Fn (X : Integer := 0) return Integer is (X + 1);

   procedure Separate_Body (S : String) is separate;

   --  a separate body with no spec: the stub is the first declaration
   procedure Stub_Only (W : Integer) is separate;

   --  a body with no spec
   procedure Body_Only (K : Integer) is
   begin
      null;
   end Body_Only;

   procedure Gen (V : T) is
   begin
      null;
   end Gen;

   function "+" (L, R : Rec) return Rec is ((F => L.F + R.F));

   --  an instance of a generic subprogram
   procedure Inst is new Gen (Integer);
end Pkg;
