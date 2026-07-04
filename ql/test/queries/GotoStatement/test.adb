procedure Test is
   X : Integer := 0;
begin
   X := X + 1;
   goto Done;             --  BAD
   X := X + 2;
   <<Done>>
   X := X + 3;
end Test;
