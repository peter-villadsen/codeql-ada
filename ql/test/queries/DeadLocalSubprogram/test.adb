procedure TopLevel is             --  fine, not nested
begin
   null;
end TopLevel;

with Missing_Pkg;  --  not available: calls into it do not resolve, nor do their arguments
procedure Outer is
   procedure Dead is               --  BAD, never called
   begin
      null;
   end Dead;

   procedure Dead_With_Spec;
   procedure Dead_With_Spec is     --  BAD, never called (has separate spec)
   begin
      null;
   end Dead_With_Spec;

   procedure Live is               --  fine, called below
   begin
      null;
   end Live;

   procedure Taken is              --  fine, address taken below
   begin
      null;
   end Taken;

   procedure Helper (X : Integer) is  --  only call is unresolved (argument from a missing package): fine (D-026)
   begin
      null;
   end Helper;

   type Proc_Access is access procedure;
   P : Proc_Access;
begin
   Live;
   P := Taken'Access;
   Helper (Missing_Pkg.Value);
end Outer;
