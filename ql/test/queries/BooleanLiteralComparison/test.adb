procedure Test is
   Flag : Boolean := True;
   X, Y : Integer := 0;
begin
   if Flag = True then          --  BAD
      null;
   end if;
   if Flag /= False then        --  BAD
      null;
   end if;
   if Flag then                 --  fine
      null;
   end if;
   if X = Y then                --  fine, not boolean literal
      null;
   end if;
end Test;
