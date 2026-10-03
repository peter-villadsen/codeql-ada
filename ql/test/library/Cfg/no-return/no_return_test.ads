package No_Return_Test is
   procedure Fail (Msg : String) with No_Return;
   function F (B : Boolean) return Integer;
   procedure G;
end No_Return_Test;
