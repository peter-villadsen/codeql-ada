with Ada.Text_IO;
package body Lazy is
   function Size return Integer is (Util.Compute);  -- not reported: only called later

   Limit : Integer := 0;
begin
   Ada.Text_IO.Put_Line ("init");  -- not reported: language-defined
end Lazy;
