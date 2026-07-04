procedure Test is
   I : Integer := 0;
   Done : Boolean := False;
begin
   while not Done loop           --  BAD
      null;
   end loop;

   for J in 1 .. 10 loop         --  BAD
      null;
   end loop;

   for J in 1 .. 10 loop         --  fine, does something
      I := I + J;
   end loop;
end Test;
