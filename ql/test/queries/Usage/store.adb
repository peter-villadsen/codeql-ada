package body Store is
   Total : Integer := 0;
   Seed : Integer := 5;                  -- reported: not written; could be constant
   Never : Integer;                      -- reported: not written

   procedure Put (X : Count) is
   begin
      Total := Total + Integer (X) + Seed + Limit + Hidden + Never;
   end Put;

   procedure Forgotten is null;

   function Double (X : Integer) return Integer is (2 * X);
   F : Int_Fn := Double'Access;

   procedure Gen is null;

   procedure Update (A : in out Integer; B : in out Integer; C : out Integer) is  -- A reported; C reported
   begin
      B := A;
      if B > 0 then
         raise Fail;
      end if;
   exception
      when Caught =>
         null;
   end Update;

   task Idle;                            -- reported: not called
   task body Idle is
   begin
      null;
   end Idle;

   protected body Guard is
      procedure Touch is
      begin
         null;
      end Touch;
   end Guard;
begin
   Put (1);
   Guard.Touch;
   Update (Total, Total, Total);
   if F (1) > 0 then
      raise Caught;
   end if;
end Store;
