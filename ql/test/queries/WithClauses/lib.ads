with Ada.Text_IO, Ada.Strings;                      --  multiple_names
with Helper;                                        --  movable: only the body uses it
with Hidden;                                        --  movable: only the private part uses it
limited with Other;                                 --  limited
package Lib is
   procedure Show;
private
   X : Integer := Hidden.Value;
end Lib;
