with Ada.Text_IO;
package body Test is
   procedure Put (S : String) renames Ada.Text_IO.Put_Line;     --  procedure
   function Twice (X : Integer) return Integer is (2 * X);
   function Double (X : Integer) return Integer renames Twice;  --  BAD: synonym
   function Plus (L, R : Integer) return Integer renames "+";   --  operator
   function "-" (L, R : Integer) return Integer renames Plus;   --  as_operator, renaming
   Count : Integer := 0;
   Total : Integer renames Count;                              --  BAD: synonym, object
   package IO renames Ada.Text_IO;                             --  package, library_unit
   Failure : exception renames Constraint_Error;               --  exception
   function Get return Integer is (Count);
   Value : Integer renames Get;                                --  function_call
   procedure Show (X : Integer);
   procedure Show_Impl (X : Integer) is null;
   procedure Show (X : Integer) renames Show_Impl;             --  as_body
   procedure Run is
   begin
      declare
         Local : Integer renames Count;                        --  block
      begin
         null;
      end;
   end Run;
end Test;
