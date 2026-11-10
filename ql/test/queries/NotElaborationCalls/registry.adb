package body Registry is

   procedure Register (Name : String) is
   begin
      null;
   end Register;

   procedure Setup is                         -- called only during elaboration
   begin
      Register ("setup");                     -- allowed
   end Setup;

   procedure Late is                          -- called from Main: runs later
   begin
      Register ("late");                      -- reported
      Default := new Integer'(1);             -- reported
   end Late;

   procedure Never_Called is                  -- no call: may run any time
   begin
      Register ("never");                     -- reported
   end Never_Called;

begin
   Register ("body");                         -- allowed
   Setup;
end Registry;
