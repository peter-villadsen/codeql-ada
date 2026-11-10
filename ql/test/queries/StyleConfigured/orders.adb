with Ada.Text_IO;
package body Orders is
   package TIO renames Ada.Text_IO;
   procedure Good (A : in Integer; B : in out Integer; C : out Integer; D : in Integer := 0) is
   begin
      C := A + B + D + 2 * 3;                      -- exposed_literal 3, not 2
      Ada.Text_IO.Put_Line ("x");                  -- renamed_entity
      TIO.Put_Line ("y");
   end Good;
   procedure Bad (C : out Integer; A : in Integer) is
   begin
      C := A;
   end;                                           -- no_closing_name: longer than 3 lines
   procedure Short_Name is null;
   procedure Implicit (X : Integer) is null;      -- default_in
end Orders;
