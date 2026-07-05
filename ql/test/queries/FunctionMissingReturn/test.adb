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
begin
   null;
end Test;
