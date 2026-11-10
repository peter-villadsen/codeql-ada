with Util;
package body Indirect is
   function Helper return Integer is
   begin
      return Util.Compute;  -- reported: called during elaboration
   end Helper;

   procedure Inst is new Util.Gen_Proc;  -- reported once with the call above
begin
   Value := Helper;
end Indirect;
