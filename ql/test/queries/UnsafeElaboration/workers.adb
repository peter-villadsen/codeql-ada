with Util;
package body Workers is
   task Runner;
   task body Runner is
      X : Integer := Util.Compute;  -- reported: tasks start during elaboration
   begin
      null;
   end Runner;
end Workers;
