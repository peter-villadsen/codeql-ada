--  Shapes the text tree should show as they are: a call, a type conversion, an
--  indexed qualified expression, a concatenation chain and a membership test.
procedure Test is
   type Arr is array (1 .. 2) of Integer;
   type Count is new Integer;
   function F (X : Integer) return Integer is (X);
   A : Arr := (1, 2);
   C : Count := Count (F (1));
   S : constant String := "a" & "b" & "c";
   B : Boolean := Arr'(3, 4) (1) in 1 | 3;
begin
   null;
end Test;
