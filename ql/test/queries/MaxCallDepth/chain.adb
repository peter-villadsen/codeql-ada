procedure Chain is
   procedure P1 is
   begin
      null;
   end P1;

   procedure P2 is
   begin
      P1;
   end P2;

   procedure P3 is
   begin
      P2;
   end P3;

   procedure P4 is
   begin
      P3;
   end P4;

   procedure P5 is
   begin
      P4;
   end P5;

   procedure P6 is
   begin
      P5;
   end P6;

   procedure P7 is
   begin
      P6;
   end P7;

   procedure P8 is
   begin
      P7;
   end P8;

   procedure P9 is
   begin
      P8;
   end P9;

   procedure P10 is
   begin
      P9;
   end P10;

   procedure P11 is
   begin
      P10;
   end P11;

   procedure P12 is
   begin
      P11;
   end P12;

   procedure P13 is
   begin
      P12;
   end P13;

   procedure P14 is
   begin
      P13;
   end P14;

   procedure P15 is
   begin
      P14;
   end P15;

   procedure P16 is
   begin
      P15;
   end P16;

   procedure P17 is
   begin
      P16;
   end P17;
begin
   P17;  -- depth 17 > 15
   P15;  -- depth 15: within the limit
   P16;  -- depth 16 > 15
end Chain;
