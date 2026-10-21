package body Test is
   Count : Integer := 0;
   type Item is new Integer;
   procedure Put (X : Integer) is null;

   procedure Run (Count : Integer) is          --  BAD: parameter hides Count
      Item : Integer := Count;                 --  different family: a type is hidden
      procedure Put (X : Float) is null;       --  overloading, not hiding
   begin
      for Count in 1 .. 3 loop                 --  BAD: hides the parameter
         Put (Float (Count));
      end loop;
      declare
         Total : Integer := 0;
      begin
         declare
            Total : Integer := 1;              --  BAD: hides the outer block's Total
         begin
            null;
         end;
      end;
   end Run;

   procedure Show (Value : Integer);
   procedure Show (Value : Integer) is null;  --  fine: the completion

   procedure Put_Twice renames Test.Put_Twice_Impl;   --  completion by renaming
   procedure Put_Twice_Impl is null;
end Test;
