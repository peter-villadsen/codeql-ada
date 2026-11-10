with Gen; use Gen;

procedure Test (N : Integer) is
   I, J : aliased Integer := 0;
   R, S : Rec;
   A    : Arr;
   P, Q : Int_Ptr := I'Access;

   --  variables
   procedure Swap_Same is new Swap (I, I);                 -- certain
   procedure Swap_Named is new Swap (Y => J, X => J);      -- certain
   procedure Swap_Distinct is new Swap (I, J);             -- distinct
   procedure Update_Part is new Update (R, R.A);           -- certain: a component of R
   procedure Update_Other is new Update (R, S.A);          -- distinct
   procedure Swap_Comps is new Swap (R.A, R.B);            -- distinct components
   procedure Swap_Comps_Same is new Swap (R.A, R.A);       -- certain
   procedure Swap_Elems is new Swap (A (1), A (1));        -- certain: same static index
   procedure Swap_Elems_2 is new Swap (A (1), A (2));      -- distinct static indices
   procedure Swap_Dyn is new Swap (A (N), A (1));          -- possible
   procedure Swap_Deref is new Swap (P.all, Q.all);        -- unlikely
   procedure Swap_Deref_Same is new Swap (P.all, P.all);   -- certain
   procedure Show_Same is new Show (N, N);                 -- in formals: not checked

   --  types
   package Pair_Same is new Pair (Integer, Integer);       -- certain
   package Pair_Class is new Pair (Rec, Rec'Base);         -- distinct (attribute)
   package Pair_Diff is new Pair (Integer, Float);         -- distinct
   package Pair_Base is new Pair (Rec'Base, Rec'Base);     -- certain

   --  subprograms
   procedure Both_Same is new Both (Step, Step);           -- certain
   procedure Both_Renamed is new Both (Step, Step_Again);  -- certain, through the renaming
   procedure Both_Diff is new Both (Step, Other);          -- distinct
   procedure Ops_Predef is new Ops ("+", "+");             -- predefined operators: not told apart

   --  packages
   procedure Packs_Same is new Packs (Pair_Same, Pair_Same); -- certain
   procedure Packs_Diff is new Packs (Pair_Same, Pair_Diff); -- distinct
begin
   null;
end Test;
