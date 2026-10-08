package body Shapes is
   Calls : Natural := 0;

   function Area (C : Circle) return Integer is
      R : constant Integer := C.Radius;
      P : Point renames C.Origin;
   begin
      Calls := Calls + 1;
      for I in 1 .. 3 loop
         Count := Count + I;
      end loop;
      return R * R + P.X;
   end Area;
end Shapes;
