package Gen is

   type Rec is record
      A, B : Integer;
   end record;

   type Arr is array (1 .. 10) of Integer;

   type Int_Ptr is access all Integer;

   generic
      X : in out Integer;
      Y : in out Integer;
   procedure Swap;

   generic
      X : in out Rec;
      Y : in out Integer;
   procedure Update;

   generic
      V : in Integer;
      W : in Integer;
   procedure Show;

   generic
      type T1 is private;
      type T2 is private;
   package Pair is
      procedure Nothing;
   end Pair;

   generic
      with procedure P1;
      with procedure P2;
   procedure Both;

   generic
      with function Op1 (L, R : Integer) return Integer;
      with function Op2 (L, R : Float) return Float;
   procedure Ops;

   generic
      with package G1 is new Pair (<>);
      with package G2 is new Pair (<>);
   procedure Packs;

   procedure Step;
   procedure Other;
   procedure Step_Again renames Step;

end Gen;
