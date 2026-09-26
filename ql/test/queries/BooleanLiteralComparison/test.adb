procedure Test is
   type Tri is (False, True, Unknown);
   type My_Bool is new Boolean;
   Flag : Boolean := True;
   T : Tri := Unknown;
   M : My_Bool := My_Bool'First;
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
   if Flag = Standard.True then --  BAD, qualified
      null;
   end if;
   if T = True then             --  fine, a user enumeration literal
      null;
   end if;
   if M = False then            --  BAD, inherited by a type derived from Boolean
      null;
   end if;
end Test;
