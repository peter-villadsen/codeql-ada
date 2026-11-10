package body Gen is

   procedure Swap is
      T : constant Integer := X;
   begin
      X := Y;
      Y := T;
   end Swap;

   procedure Update is
   begin
      X.A := Y;
   end Update;

   procedure Show is
   begin
      null;
   end Show;

   package body Pair is
      procedure Nothing is
      begin
         null;
      end Nothing;
   end Pair;

   procedure Both is
   begin
      P1;
      P2;
   end Both;

   procedure Ops is
   begin
      null;
   end Ops;

   procedure Packs is
   begin
      null;
   end Packs;

   procedure Step is
   begin
      null;
   end Step;

   procedure Other is
   begin
      null;
   end Other;

end Gen;
