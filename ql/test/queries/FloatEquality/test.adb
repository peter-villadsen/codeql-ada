procedure Test is
   type My_Float is digits 6;
   F1, F2 : My_Float := 0.0;
   I1, I2 : Integer := 0;
begin
   if F1 = F2 then              --  BAD
      null;
   end if;
   if F1 /= F2 then             --  BAD
      null;
   end if;
   if I1 = I2 then              --  fine, integer
      null;
   end if;
end Test;
