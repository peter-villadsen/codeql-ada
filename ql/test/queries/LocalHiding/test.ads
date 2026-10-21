package Test is
   procedure Put_Twice;
   type Color is (Red, Green);
   function Red return Integer;                --  overloads the literal Red
   type Light is (Red, Amber);                 --  overloads Red again
end Test;
