package body Ops is
   procedure Swap (X, Y : in out Integer) is
      T : constant Integer := X;
   begin
      X := Y;
      Y := T;
   end Swap;

   procedure Copy (From : Rec; To : out Rec) is
   begin
      To := From;
   end Copy;

   procedure Update (R : in out Rec; V : out Integer) is
   begin
      V := R.A;
      R.B := V;
   end Update;

   function Bump (X : in out Integer; Y : in out Integer) return Integer is
   begin
      X := X + 1;
      Y := Y + 1;
      return X + Y;
   end Bump;

   procedure Show (X, Y : Integer) is
   begin
      null;
   end Show;
end Ops;
