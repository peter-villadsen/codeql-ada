package body Locks is
   procedure Wait_For_Device is
   begin
      null;
   end Wait_For_Device;

   procedure Compute (X : in out Integer) is
   begin
      X := X + 1;
   end Compute;
end Locks;
