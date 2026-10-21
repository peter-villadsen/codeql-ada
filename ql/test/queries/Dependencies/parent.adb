with Parent.Pub;                 --  BAD: own public child
with Parent.Priv;                --  BAD: own private child
with Parent.Pub.Deep;            --  BAD: own (grand)child
with Ada.Text_IO, Ada.Text_IO;   --  raw counts both
package body Parent is
   procedure Show is
   begin
      Ada.Text_IO.Put_Line (Integer'Image (Pub.Y + Priv.Z + Pub.Deep.W));
   end Show;
end Parent;
