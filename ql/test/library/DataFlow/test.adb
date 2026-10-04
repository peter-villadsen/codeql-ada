with Shapes;

procedure Test is
   function Source (Id : Integer) return Integer is (Id);
   procedure Sink (X : Integer) is null;

   --  Down through parameters, two frames: Test -> Mid -> Leaf.
   procedure Leaf (B : Integer) is
   begin
      Sink (B);  -- $ flow=1 flow=26 flow=29
   end Leaf;

   procedure Mid (A : Integer) is
   begin
      Leaf (A);
   end Mid;

   --  Named and mixed associations bind by formal name, not by position.
   procedure Two (X : Integer; Y : Integer) is
   begin
      Sink (X);  -- $ flow=3
      Sink (Y);  -- $ flow=2
   end Two;

   --  Up through function results, two frames; Get_Outer is a parameterless call.
   function Get_Inner return Integer is
   begin
      return Source (4);
   end Get_Inner;

   function Get_Outer return Integer is (Get_Inner);

   --  Up through an `out` parameter, two frames: Set_Inner -> Set_Outer -> Test.
   procedure Set_Inner (R : out Integer) is
   begin
      R := Source (5);
   end Set_Inner;

   procedure Set_Outer (R : out Integer) is
   begin
      Set_Inner (R);
   end Set_Outer;

   --  In through one parameter and out through another.
   procedure Copy (From : Integer; To : out Integer) is
   begin
      To := From;
   end Copy;

   --  A value-preserving function: flow through it must respect the call site.
   function Id (P : Integer) return Integer is (P);

   --  `in out`: the value comes in, and whatever the callee leaves goes back out.
   procedure Keep (Z : in out Integer) is
   begin
      null;
   end Keep;

   procedure Replace (Z : in out Integer) is
   begin
      Z := Source (11);
   end Replace;

   procedure Show (Z : in out Integer) is
   begin
      Sink (Z);  -- $ flow=10
   end Show;

   --  Parameters of a body with a separate declaration.
   procedure Fwd (F : Integer);

   procedure Fwd (F : Integer) is
   begin
      Sink (F);  -- $ flow=13
   end Fwd;

   --  Two `out` formals written back at one exit stay apart.
   procedure Two_Out (P : out Integer; Q : out Integer) is
   begin
      P := Source (14);
      Q := 0;
   end Two_Out;

   --  A multi-name group: `A` and `B` are formals 0 and 1.
   procedure Swap (A, B : in out Integer) is
      T : constant Integer := A;
   begin
      A := B;
      B := T;
   end Swap;

   --  v1 limitations (docs/dataflow-design.md), pinned as MISSING.

   --  Calls to a generic *subprogram* instance are unresolved: the instance has no body.
   generic
   function G_Id (P : Integer) return Integer;
   function G_Id (P : Integer) return Integer is (P);
   function Inst_Id is new G_Id;

   --  A subprogram of a generic *package* instance resolves to its declaration in the
   --  generic, so flow enters the generic's one body (shared by all instances; each
   --  return still goes back to its own call site).
   generic
   package G_Pkg is
      function Pass (P : Integer) return Integer;
   end G_Pkg;

   package body G_Pkg is
      function Pass (P : Integer) return Integer is (P);
   end G_Pkg;

   package Inst_A is new G_Pkg;
   package Inst_B is new G_Pkg;

   --  User-defined operators are calls: operands bind to formals by position.
   type Tag is new Integer;
   function "+" (L : Integer; R : Tag) return Integer is (L);
   function "not" (X : Integer) return Integer is (X);
   function "*" (L : Tag; R : Integer) return Integer is (0);

   --  Access-to-subprogram calls are unresolved.
   type Int_Fn is access function (P : Integer) return Integer;
   Fn : constant Int_Fn := Id'Access;

   --  Task entry calls are unresolved.
   task Worker is
      entry Put (X : Integer);
   end Worker;

   task body Worker is
   begin
      accept Put (X : Integer) do
         Sink (X);  -- $ MISSING: flow=24
      end Put;
   end Worker;

   --  A call to a separate body.
   procedure Sep (X : Integer) is separate;

   --  A call through a subprogram renaming reaches the renamed body.
   procedure Leaf_Alias (C : Integer) renames Leaf;

   --  ... and so does a call to a declaration completed by a renaming-as-body.
   procedure Leaf_Rab (C : Integer);
   procedure Leaf_Rab (C : Integer) renames Leaf;

   --  A default parameter value flows into the formal: it is evaluated at the callee's entry.
   procedure Dflt (X : Integer := Source (27)) is
   begin
      Sink (X);  -- $ flow=27
   end Dflt;

   --  ... also when every call passes an actual (the callee-side over-approximation).
   procedure Dflt2 (X : Integer := Source (36)) is
   begin
      Sink (X);  -- $ SPURIOUS: flow=36
   end Dflt2;

   --  An extended return statement returns its object.
   function Ext return Integer is
   begin
      return R : constant Integer := Source (30) do
         null;
      end return;
   end Ext;

   --  A protected operation is a call; the prefix is the protected object, not a formal.
   protected Box is
      procedure Put (X : Integer);
   end Box;

   protected body Box is
      procedure Put (X : Integer) is
      begin
         Sink (X);  -- $ flow=31
      end Put;
   end Box;

   --  An object of a protected type: the actuals are not shifted as for a prefixed view.
   protected type Cell is
      procedure Put (X : Integer; Y : Integer);
   end Cell;

   protected body Cell is
      procedure Put (X : Integer; Y : Integer) is
      begin
         Sink (Y);  -- $ flow=37
      end Put;
   end Cell;

   Obj : Cell;

   V1, V2, V3, V4, V6, V7, V8, V9, V10, V11, V12 : Integer;
   Sq : Shapes.Square;
begin
   Mid (Source (1));
   Two (y => Source (2), X => 0);   --  designators ignore case, as Ada does
   Two (Source (3), Y => 0);

   v1 := Get_Outer;                 --  and so do variable names
   Sink (V1);  -- $ flow=4

   Set_Outer (V2);
   Sink (V2);  -- $ flow=5

   Copy (Source (6), V3);
   Sink (V3);  -- $ flow=6
   Copy (To => V4, From => Source (7));
   Sink (V4);  -- $ flow=7

   Sink (Id (Source (8)));  -- $ flow=8
   Sink (Id (0));

   V6 := Source (10);
   Keep (V6);
   Sink (V6);  -- $ flow=10
   Show (V6);

   V7 := 0;
   Replace (V7);
   Sink (V7);  -- $ flow=11

   --  Replace always overwrites Z, but an `out`/`in out` write-back is uncertain
   --  (D-022), so the old value is kept too.
   V8 := Source (12);
   Replace (V8);
   Sink (V8);  -- $ flow=11 SPURIOUS: flow=12

   Fwd (Source (13));

   Two_Out (V9, V10);
   Sink (V9);  -- $ flow=14
   Sink (V10);

   V11 := Source (15);
   V12 := 0;
   Swap (V11, V12);
   Sink (V12);  -- $ flow=15
   Sink (V11);  -- $ SPURIOUS: flow=15

   Sink (Inst_Id (Source (20)));  -- $ MISSING: flow=20
   Sink (Fn (Source (21)));  -- $ MISSING: flow=21

   --  Static binding through a package-qualified name is resolved ...
   Sink (Shapes.Area (Sq));  -- $ flow=22
   --  ... dispatching is not: the class-wide call binds to Shape's Area only.
   Sink (Shapes.Area (Shapes.Shape'Class (Sq)));  -- $ MISSING: flow=22
   --  ... and so is prefixed (dot) notation, where `Sq` is the first actual.
   Sink (Sq.Area);  -- $ flow=22
   Sq.Put (Source (23));
   Sq.Put (V => Source (28));

   Worker.Put (Source (24));
   Sep (Source (25));
   Leaf_Alias (C => Source (26));
   Leaf_Rab (Source (29));
   Dflt;
   Sink (Ext);  -- $ flow=30
   Dflt2 (0);
   Obj.Put (0, Source (37));
   Box.Put (Source (31));
   Sink (Inst_A.Pass (Source (32)));  -- $ flow=32
   Sink (Inst_B.Pass (0));
   Sink (Source (33) + Tag'(0));  -- $ flow=33
   Sink (not Source (34));  -- $ flow=34
   Sink (Tag'(1) * Source (35));
end Test;
