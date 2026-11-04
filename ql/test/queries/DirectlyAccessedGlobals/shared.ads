package Shared is
   Spec_Var : Integer := 0;            --  fine: in a spec, not a body

   procedure Set_Good (V : Integer);
   function Get_Good return Integer;
   procedure Bump_Alone;
   procedure Two_Writers_A;
   procedure Two_Writers_B;
   procedure Read_Write;
   function Also_Reads return Integer;
   procedure Outer;
   procedure Uses_Out;
   procedure Uses_Spec;
end Shared;
