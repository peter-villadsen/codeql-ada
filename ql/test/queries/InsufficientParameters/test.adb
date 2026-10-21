procedure Test is
   type Color is (Red, Green);
   procedure Draw (X, Y : Integer; Filled : Boolean; C : Color := Red) is null;
   function Scale (F : Float; Times : Integer) return Float is (F * Float (Times));
   X : Integer := 1;
   F : Float := 1.0;
begin
   Draw (3, 4, True);                        --  BAD: three
   Draw (X, 4, True);                        --  BAD: two
   Draw (X, X, Filled => True);              --  fine: none positional and literal
   Draw (X, -4, Filled => False, C => Green);  --  fine: one
   Draw (X, X, False, Green);                --  one (Green is not Boolean)
   F := Scale (2.0, 3 * 2);                  --  BAD: two
   X := X + 1;                               --  fine: an operator
end Test;
