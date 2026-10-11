with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

procedure Test is
   function Source (Id : Integer) return Integer is (Id);
   procedure Sink (X : Integer) is null;

   type Pair is record
      A : Integer := 0;
      B : Integer := 0;
   end record;

   type Outer is record
      P : Pair;
      C : Integer := 0;
   end record;

   type Arr is array (1 .. 10) of Integer;

   type Pair_Access is access Pair;

   package Int_Vectors is new Ada.Containers.Vectors (Positive, Integer);
   package Int_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, Integer, Ada.Strings.Hash, "=");

   --  A record filled in through an `out` formal, one component at a time.
   procedure Fill (R : out Pair) is
   begin
      R.A := Source (5);
      R.B := 0;
   end Fill;

   --  A record built by an aggregate and returned.
   function Make return Pair is ((A => Source (6), B => 0));

   --  A component read in the callee.
   procedure Use_A (R : Pair) is
   begin
      Sink (R.A);  -- $ flow=7
      Sink (R.B);
   end Use_A;

   --  An element stored in the callee, through an `in out` formal.
   procedure Put (V : in out Arr) is
   begin
      V (3) := Source (8);
   end Put;

   R1, R2, R3, R4, R5 : Pair;
   O1 : Outer;
   V1, V2 : Arr := (others => 0);
   Ptr : Pair_Access := new Pair;
   Vec, Vec2 : Int_Vectors.Vector;
   Map : Int_Maps.Map;
begin
   --  Store and read back in the same subprogram; the other component stays clean.
   R1.A := Source (1);
   Sink (R1.A);  -- $ flow=1
   Sink (R1.B);

   --  Nested components.
   O1.P.B := Source (2);
   Sink (O1.P.B);  -- $ flow=2
   Sink (O1.P.A);
   Sink (O1.C);

   --  Array elements: an element read sees every element store (no index tracking).
   V1 (1) := Source (3);
   Sink (V1 (2));  -- $ flow=3
   V2 := (others => Source (4));
   Sink (V2 (5));  -- $ flow=4

   Fill (R2);
   Sink (R2.A);  -- $ flow=5
   Sink (R2.B);

   R3 := Make;
   Sink (R3.A);  -- $ flow=6
   Sink (R3.B);

   R4.A := Source (7);
   Use_A (R4);

   Put (V1);
   Sink (V1 (3));  -- $ flow=3 flow=8

   --  A whole record copied: its components go with it.
   R5 := R1;
   Sink (R5.A);  -- $ flow=1

   --  Through an access value (implicit dereference).
   Ptr.A := Source (9);
   Sink (Ptr.A);  -- $ flow=9
   Ptr.all.B := Source (10);
   Sink (Ptr.all.B);  -- $ flow=10
   Sink (Ptr.B);  -- $ flow=10

   --  A positional record aggregate: which component gets which value is not worked out.
   R5 := (Source (11), 0);
   Sink (R5.A);  -- $ MISSING: flow=11

   --  An array iterated with `for ... of`: the loop variable is an element.
   for E of V1 loop
      Sink (E);  -- $ flow=3 flow=8
   end loop;

   --  Standard containers: stored by Append / Insert / Include / Replace_Element, read
   --  back by Element, First_Element, Last_Element, indexing, cursors and loops.
   Vec.Append (Source (12));
   Sink (Vec.Element (1));  -- $ flow=12
   Sink (Int_Vectors.First_Element (Vec));  -- $ flow=12
   Sink (Vec (1));  -- $ flow=12
   for X of Vec loop
      Sink (X);  -- $ flow=12
   end loop;
   for C in Vec.Iterate loop
      Sink (Int_Vectors.Element (C));  -- $ flow=12
   end loop;
   Sink (Int_Vectors.Element (Vec.First));  -- $ flow=12
   Sink (Vec2.Element (1));
   Int_Vectors.Append (Vec2, Source (13));
   Sink (Vec2.Last_Element);  -- $ flow=13
   Map.Include ("k", Source (14));
   Sink (Map.Element ("k"));  -- $ flow=14
   Sink (Map ("k"));  -- $ flow=14
end Test;
