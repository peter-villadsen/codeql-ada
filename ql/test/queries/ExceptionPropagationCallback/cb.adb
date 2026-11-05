package body CB is
   Count : Integer := 0;

   procedure Register (Callback : Handler) is null;
   procedure Log (Callback : Handler) is null;

   procedure Propagates is
   begin
      Count := Count / 0;
   end Propagates;

   procedure Safe is
   begin
      Count := 0;
   exception
      when others =>
         null;
   end Safe;

begin
   Register (Propagates'Access);                 --  BAD: a call-back that can propagate
   Register (Callback => Safe'Access);           --  fine
   Log (Propagates'Access);                      --  fine: Log's parameter is not set as a call-back
end CB;
