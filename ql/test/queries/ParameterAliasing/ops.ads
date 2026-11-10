package Ops is
   type Rec is record
      A, B : Integer;
   end record;
   type Arr is array (1 .. 10) of Integer;
   type Int_Ptr is access all Integer;

   procedure Swap (X, Y : in out Integer);
   procedure Copy (From : Rec; To : out Rec);
   procedure Update (R : in out Rec; V : out Integer);
   function Bump (X : in out Integer; Y : in out Integer) return Integer;
   procedure Show (X, Y : Integer);
end Ops;
