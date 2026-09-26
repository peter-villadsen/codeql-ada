package body Pkg is
   procedure Down (N : Integer) is  --  recursive via the package spec: BAD
   begin
      if N > 0 then
         Down (N - 1);
      end if;
   end Down;

   procedure Over (N : Integer) is  --  calls the other overload: fine
   begin
      Over (Integer'Image (N));
   end Over;

   procedure Over (S : String) is
   begin
      null;
   end Over;
end Pkg;
