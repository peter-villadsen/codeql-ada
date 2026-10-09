procedure TopLevel is             --  fine, not nested
begin
   null;
end TopLevel;

with Missing_Pkg;  --  not available: calls into it do not resolve, nor do their arguments
procedure Outer is
   procedure Dead is               --  BAD, never called
   begin
      null;
   end Dead;

   procedure Dead_With_Spec;
   procedure Dead_With_Spec is     --  BAD, never called (has separate spec)
   begin
      null;
   end Dead_With_Spec;

   procedure Live is               --  fine, called below
   begin
      null;
   end Live;

   procedure Taken is              --  fine, address taken below
   begin
      null;
   end Taken;

   procedure Helper (X : Integer) is  --  only call is unresolved (argument from a missing package): fine (D-026)
   begin
      null;
   end Helper;

   type Proc_Access is access procedure;
   P : Proc_Access;
begin
   Live;
   P := Taken'Access;
   Helper (Missing_Pkg.Value);
end Outer;

--  Shapes the name-text pairing got wrong (Phase 12, Task 12.4).
procedure Outer2 is
   generic
      with function Transform (V : Integer) return Integer;
   procedure Never_Instantiated (V : Integer);  --  generic, no instance: BAD

   generic
      with function Transform (V : Integer) return Integer;
   procedure Instantiated (V : Integer);        --  generic with an instance: fine

   procedure Never_Instantiated (V : Integer) is
   begin
      null;
   end Never_Instantiated;

   procedure Instantiated (V : Integer) is
   begin
      null;
   end Instantiated;

   function Twice (V : Integer) return Integer is (2 * V);

   procedure Inst is new Instantiated (Twice);

   protected Obj is
      procedure Set (V : Integer);
   end Obj;

   protected body Obj is
      procedure Set (V : Integer) is              --  called through its spec: fine
      begin
         null;
      end Set;
   end Obj;
begin
   Inst (1);
   Obj.Set (2);
end Outer2;

--  Used without being named (v0.2.0 precision check): fine.
procedure Outer3 is
   type Base is abstract tagged null record;
   procedure Visit (B : Base) is abstract;
   procedure Run (B : Base'Class) is
   begin
      Visit (B);
   end Run;

   type Leaf is new Base with null record;
   overriding procedure Visit (L : Leaf) is       --  called by dispatching
   begin
      null;
   end Visit;

   generic
      type T is private;
      with function Compare (L, R : T) return Boolean is <>;
   function Max (L, R : T) return T;
   function Max (L, R : T) return T is (if Compare (L, R) then L else R);

   function Compare (L, R : Integer) return Boolean is            --  box default
   begin
      return L > R;
   end Compare;

   function Int_Max is new Max (Integer);

   type Pair is record
      A, B : Integer;
   end record;

   function "=" (L, R : Pair) return Boolean is                   --  generic actual
   begin
      return L.A = R.A;
   end "=";

   --  the generic is missing, so the actual "=" does not resolve
   package Pair_Sets is new Missing_Pkg.Sets (Pair, "=" => "=");
begin
   Run (Leaf'(null record));
   if Int_Max (1, 2) = 2 then
      null;
   end if;
end Outer3;
