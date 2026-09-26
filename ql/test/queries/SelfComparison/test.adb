procedure Test (X : Integer; Y : Integer) is
   type Pair is record
      Size : Integer;
      Flag : Boolean;
   end record;
   L, R : Pair;
   A, B : Integer;
   Flag : Boolean;
begin
   Flag := X = X;
   Flag := X <= X;
   Flag := X = Y;
   Flag := X = 0;
   Flag := L.Size = R.Size;   --  fine, different prefixes
   Flag := L.Size = L.Size;   --  BAD
   Flag := A <= B;            --  fine, one declaration, two names (D-024)
   Flag := A = A;             --  BAD
end Test;
