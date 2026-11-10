package body Shared is

   procedure Bump is
   begin
      Counter := Counter + 1;
   end Bump;

   function Get_Total return Integer is
   begin
      return Total;
   end Get_Total;

   procedure Set_Only is
   begin
      Only_Proc := Only_Proc + 1;
   end Set_Only;

end Shared;
