procedure Test is
   --  BUG: falls off the end when X <= 0, no return on that path
   function F1 (X : Integer) return Integer is
   begin
      if X > 0 then
         return X;
      end if;
   end F1;

   --  fine: every path returns
   function F2 (X : Integer) return Integer is
   begin
      if X > 0 then
         return X;
      else
         return -X;
      end if;
   end F2;

   --  fine: single unconditional return
   function F3 (X : Integer) return Integer is
   begin
      return X * 2;
   end F3;

   --  fine: a procedure never needs a return
   procedure P1 (X : Integer) is
   begin
      if X > 0 then
         null;
      end if;
   end P1;

   --  fine: expression function always yields a value
   function F4 (X : Integer) return Integer is (X + 1);

   procedure Fail (Msg : String) with No_Return;
   procedure Fail (Msg : String) is
   begin
      raise Program_Error with Msg;
   end Fail;

   --  fine: the last statement is a call to a No_Return procedure, which only raises
   function F5 (X : Integer) return Integer is
   begin
      if X > 0 then
         return X;
      end if;
      Fail ("negative");
   end F5;
begin
   null;
end Test;
