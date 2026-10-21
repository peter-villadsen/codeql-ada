procedure Test is
   A, B, C : Integer := 1;
   X : Integer;
   function F (I : Integer) return Integer is (I);
begin
   X := A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A;   --  BAD: 21 items
   X := A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A + A;   --  fine: 20 items
   X := (A + B) * (C - A) + F (A + B + C);   --  6 items; F's argument is 3 of its own
   X := (if A > B then A + B else -C);       --  1 item; inside, 2, 2 and 1
end Test;
