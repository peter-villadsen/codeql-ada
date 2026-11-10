with Ops; use Ops;

procedure Test (N : Integer) is
   I, J : aliased Integer := 0;
   R    : Rec;
   A    : Arr := (others => 0);
   P, Q : Int_Ptr := I'Access;
   K    : Integer;
begin
   Swap (I, I);                   -- certain
   Swap (Y => J, X => J);         -- certain, named
   Swap (I, J);                   -- distinct
   Swap (R.A, R.B);               -- distinct components
   Swap (R.A, R.A);               -- certain
   Swap (A (1), A (1));           -- certain
   Swap (A (1), A (2));           -- distinct static indices
   Swap (A (N), A (1));           -- possible
   Swap (P.all, Q.all);           -- unlikely
   Update (R, R.A);               -- certain: a component of R
   Copy (R, R);                   -- with_in: R is in and out
   Show (I, I);                   -- in only: never aliasing
   K := Bump (I, I);              -- certain, a function call
end Test;
