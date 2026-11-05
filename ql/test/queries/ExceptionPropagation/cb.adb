with Ada.Exceptions;
package body CB is
   Count : Integer := 0;

   procedure Register (Callback : Handler) is null;

   procedure Exported_Pragma (X : Integer) is   --  BAD: exported, no handler
   begin
      Count := Count / X;
   end Exported_Pragma;

   procedure Exported_Aspect (X : Integer) is   --  BAD: exported, its handler re-raises
   begin
      Count := Count / X;
   exception
      when others =>
         raise;
   end Exported_Aspect;

   procedure Exported_Safe (X : Integer) is     --  fine
      Ratio : Integer := 100 / X;                --  propagates from level 1 (a call of "/")
   begin
      Count := Ratio;
   exception
      when others =>
         Count := 0;
   end Exported_Safe;

   procedure Exported_Null is null;             --  fine: a null procedure

   procedure Not_Exported (X : Integer) is      --  fine: not exported
   begin
      Count := X;
   end Not_Exported;

   task Unsafe_Task;                            --  BAD: no handler

   task body Unsafe_Task is
   begin
      Count := Count + 1;
   end Unsafe_Task;

   task Reporting_Task;                          --  BAD: its handler raises

   task body Reporting_Task is
   begin
      Count := Count + 1;
   exception
      when E : others =>
         Ada.Exceptions.Raise_Exception (Program_Error'Identity, "failed");
   end Reporting_Task;

   task Safe_Task;                               --  fine

   task body Safe_Task is
      Limit : constant Integer := 10;            --  level 3: an object
      Start : Integer := Count;                  --  level 2: a variable
   begin
      Count := Count + Limit + Start;
   exception
      when others =>
         null;
   end Safe_Task;

   procedure Local_Unhandled is
      Oops : exception;                          --  BAD: no handler
   begin
      raise Oops;
   end Local_Unhandled;

   procedure Local_By_Name is
      Oops : exception;                          --  fine: handled by name
   begin
      raise Oops;
   exception
      when Oops =>
         Count := 0;
   end Local_By_Name;

   procedure Local_By_Others is
      Oops, Other : exception;                   --  fine: both handled by others
   begin
      raise Oops;
   exception
      when others =>
         Count := 0;
   end Local_By_Others;

   procedure Local_Reraised is
      Oops : exception;
   begin
      raise Oops;
   exception
      when Oops =>
         raise;                                  --  BAD: re-raised out of its scope
   end Local_Reraised;

   procedure Local_Raised_In_Handler is
      Oops : exception;
   begin
      Count := Count / 0;
   exception
      when others =>
         raise Oops;                             --  BAD: raised out of its scope
   end Local_Raised_In_Handler;

   procedure In_Block is
   begin
      declare
         Oops : exception;                       --  BAD: no handler in the block
      begin
         raise Oops;
      end;
   end In_Block;

   procedure Propagates is
   begin
      Count := Count / 0;
   end Propagates;

   procedure Safe is
   begin
      Count := 0;
   exception
      when others =>
         null;
   end Safe;

begin
   Register (Propagates'Access);                 --  BAD with the call-back setting
   Register (Safe'Access);                       --  fine
end CB;
