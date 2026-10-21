with Ada.Text_IO;                                   --  BAD: already withed by the spec
with Helper;                                        --  fine: the body uses it
package body Lib is
   procedure Show is
   begin
      Ada.Text_IO.Put_Line (Integer'Image (Helper.Value + X));
   end Show;
end Lib;
