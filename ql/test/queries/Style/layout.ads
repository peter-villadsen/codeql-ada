with Ada.Text_IO; use Ada.Text_IO;  -- not reported: flexible
package Layout is
   Max_Count : constant Integer := 10000;    -- numeric_literal
   Big_Count : constant Integer := 10_000;
   Mask : constant := 16#ff#;               -- casing_number
   Scale : constant Float := 1.0e3;          -- casing_exponent
   procedure Put (X : Integer);
   procedure Get (X : in Integer; Y : out Integer);
   procedure Ref (P : access Integer);
end Layout;
