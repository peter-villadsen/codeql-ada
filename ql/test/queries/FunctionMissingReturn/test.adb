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

--  A No_Return call that does not resolve, as with a missing dependency (v0.2.0
--  precision check): the argument names a package that is not there.
package Errors is
   procedure Fail (Msg : String) with No_Return;
end Errors;

with Errors;
function Checked (X : Integer) return Integer is   --  fine: Fail never returns
begin
   if X > 0 then
      return X;
   end if;
   Errors.Fail (Missing_Pkg.Describe (X));
end Checked;

with Errors;
function Checked_Else (X : Integer) return Integer is   --  fine: the else branch fails
begin
   if X > 0 then
      return X;
   else
      Errors.Fail (Missing_Pkg.Describe (X));
   end if;
end Checked_Else;
