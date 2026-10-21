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

--  A return through a GNAT finally part (CFG migration, Step 5): the finally part
--  continues the return, so the function cannot run off its end.
function Returns_Through_Finally (X : Integer) return Integer is   --  fine
begin
   begin
      return X;
   finally
      null;
   end;
end Returns_Through_Finally;

function Returns_Both_Ways (C : Boolean) return Integer is   --  fine
begin
   begin
      if C then
         return 1;
      else
         return 2;
      end if;
   finally
      null;
   end;
end Returns_Both_Ways;

--  AdaControl Abnormal_Function_Return: exception handlers of a function.
function Handler_Falls_Off (X : Integer) return Integer is   --  fine: body returns
begin
   return 10 / X;
exception
   when Constraint_Error =>   --  BUG: completes normally
      null;
   when others =>             --  fine: re-raises
      raise;
end Handler_Falls_Off;

function Handler_Returns (X : Integer) return Integer is   --  fine
begin
   return 10 / X;
exception
   when Constraint_Error =>
      return 0;
   when Program_Error =>
      if X > 0 then
         return 1;
      else
         raise;
      end if;
end Handler_Returns;

function Both_Fall_Off (X : Integer) return Integer is   --  BUG: body, and the handler
begin
   if X > 0 then
      return X;
   end if;
exception
   when others =>   --  BUG
      null;
end Both_Fall_Off;

function Nested_Handler (X : Integer) return Integer is   --  fine: falls to the return
begin
   begin
      return 10 / X;
   exception
      when others =>
         null;
   end;
   return 0;
end Nested_Handler;

with Ada.Text_IO;
function Reached_Handler (X : Integer) return Integer is   --  fine: body returns
begin
   Ada.Text_IO.Put_Line ("x");
   return X;
exception
   when others =>   --  BUG: reached from the call, and completes normally
      Ada.Text_IO.Put_Line ("failed");
end Reached_Handler;

with Ada.Text_IO;
function Reached_Handler_Ok (X : Integer) return Integer is   --  fine
begin
   Ada.Text_IO.Put_Line ("x");
   return X;
exception
   when Constraint_Error =>
      Ada.Text_IO.Put_Line ("failed");
      return 0;
   when others =>
      Ada.Text_IO.Put_Line ("failed");
      raise;
end Reached_Handler_Ok;
