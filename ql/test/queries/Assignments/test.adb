with Ada.Finalization;
with Globals; use Globals;
procedure Test is
   type Point is record
      X, Y, Z : Integer;
   end record;

   type Pair is record
      A, B : Integer;
   end record;

   type Holder is record
      P : Pair;
      N : Integer;
   end record;

   type Int_Access is access all Integer;

   type With_Ptr is record
      Ptr  : Int_Access;
      Size : Integer;
   end record;

   type Managed is new Ada.Finalization.Controlled with record
      Ptr : Int_Access;
   end record;

   type Address_Like is new Integer;
   type Derived_Address is new Address_Like;

   type Vec is array (1 .. 3) of Integer;
   subtype Shifted is String (5 .. 7);

   type Limited_Part is limited record
      V : Integer;
   end record;

   type Has_Limited is limited record
      L : Limited_Part;
      K : Integer;
   end record;

   Pt  : Point;
   Pr  : Pair;
   H   : Holder;
   V   : Vec;
   I, J, K : Integer := 0;
   A1, A2 : Int_Access;
   W1, W2 : With_Ptr;
   M1, M2 : Managed;
   Addr   : Address_Like;
   DA     : Derived_Address;
   S1 : String (1 .. 3) := "abc";
   S2 : Shifted := "def";               --  fine: initializations are not checked for sliding
   S3 : String (5 .. 7);
   HL : Has_Limited;

   function Next return Integer;
   function Next return Integer is (I + 1);

   Init_Dup : Int_Access := A1;         --  access_duplication, at initialization

   procedure Q (X : Integer) is null;

   procedure Nested is
   begin
      I := 1;
      I := Next;                        --  fine (query): I is not local to Nested
   end Nested;
begin
   --  repeated
   I := 1;
   I := 2;                              --  BAD: repeated, I is not read in between
   null;
   Pt.X := 1;
   J := 3;
   Pt.X := 4;                           --  BAD: repeated component, through a null and another assignment
   Q (0);                               --  a call ends the group
   K := 1;
   K := K + 1;                          --  fine (query): K is read; the library still reports it
   Q (0);
   V (1) := 1;
   V (1) := 2;                          --  BAD: repeated element with a static index
   Q (0);
   V (I) := 1;
   V (I) := 2;                          --  fine: the index is not static
   Q (0);
   S1 (1 .. 2) := "ab";
   S1 (2 .. 3) := "cd";                 --  fine: slices are dynamic
   Q (0);
   Global := 1;
   Global := Next;                      --  fine (query): Next may read Global
   Q (0);
   J := 1;
   J := Next;                           --  BAD: J is local; Next cannot see it
   Q (0);
   I := 1;
   I := Next;                           --  fine (query): Next, nested in Test, reads I
   Q (0);
   J := 5;
   Q (J);
   J := 6;                              --  fine: another group

   --  groupable
   Q (0);
   Pr.A := 1;
   Pr.B := 2;                           --  BAD: every component of Pr, one by one
   Q (0);
   Pt.X := 1;
   Pt.Y := 2;                           --  fine (query): Z is missing
   Q (0);
   H.P.A := 1;
   H.N := 2;                            --  fine (query): P is assigned in part only
   Q (0);
   Pr.A := Pr.B;
   Pr.B := 3;                           --  fine (query): Pr is read in the group
   Q (0);
   HL.L.V := 1;
   HL.K := 2;                           --  fine: a limited component
   Q (0);

   --  sliding
   S1 := S3;                            --  BAD: sliding, 5 .. 7 into 1 .. 3
   Q (0);
   S3 := S2;                            --  fine: both start at 5
   Q (0);
   S3 := "xyz";                         --  BAD: sliding, a literal into 5 .. 7
   Q (0);
   S1 := "uvw";                         --  fine
   Q (0);
   S1 := S3 (5 .. 7);                   --  fine: a slice is dynamic
   Q (0);

   --  access_duplication
   A2 := A1;                            --  access_duplication, not controlled
   Q (0);
   A2 := null;                          --  fine
   Q (0);
   A2 := new Integer'(3);               --  fine
   Q (0);
   W2 := W1;                            --  access_duplication, a component
   Q (0);
   M2 := M1;                            --  access_duplication, controlled
   Q (0);
   A2 := W1.Ptr;                        --  access_duplication, a component read
   Q (0);

   --  type
   Addr := 4;                           --  type Address_Like
   DA := 5;                             --  type Derived_Address, Address_Like with ancestor
   H.N := 3;                            --  type Holder, component
   Q (0);

   --  possible_target_name
   I := I + 1;                          --  possible_target_name, trivial
   Q (0);
   Pt.X := Pt.X * 2;                    --  possible_target_name, not trivial
   Q (0);
   V (J) := V (J) - 1;                  --  possible_target_name, not trivial
   Q (0);
   V (J) := V (I) - 1;                  --  fine
end Test;
