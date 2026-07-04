procedure TopLevel is             --  fine, not nested
begin
   null;
end TopLevel;

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

   type Proc_Access is access procedure;
   P : Proc_Access;
begin
   Live;
   P := Taken'Access;
end Outer;
