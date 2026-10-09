procedure Test is
   X : Integer := 0;
begin
   if X > 0 then                --  BAD
      null;
   end if;
   if X > 0 then                --  fine, has else
      null;
   else
      X := 1;
   end if;
   if X > 0 then                --  fine, has elsif
      null;
   elsif X < 0 then
      X := -1;
   end if;
   if X > 0 then                --  fine, does something
      X := X + 1;
   end if;
end Test;

--  A condition evaluated for its effect (v0.2.0 precision check): fine.
procedure Effect is
   Loaded : Natural := 0;
   function Load return Boolean is
   begin
      Loaded := Loaded + 1;
      return True;
   end Load;
begin
   if Load then
      null;
   end if;
end Effect;
