procedure Test is
   type Small is range 1 .. 10;
   subtype Tiny is Small range 1 .. 3;
   Max : constant := 5;
   S : Small := 1;
   T : Tiny := 1;
   I : Integer := 0;
   N : Natural := 0;
   B : Boolean := False;
   A : array (Small) of Integer := (others => 0);
begin
   S := Small (S);                         --  conversion: the same subtype
   S := Small (T);                         --  conversion: the first subtype of Tiny
   T := Tiny (S);                          --  fine: a real constraint check
   I := Integer (N);                       --  conversion: Integer is Natural's first subtype
   S := Small (3);                         --  conversion: a literal
   S := Small (Max);                       --  conversion: a named number
   I := Integer (S);                       --  fine: another type
   B := (I > 0) and (I > 0);               --  logical_redundant
   B := I > 0 or else I > 1;               --  fine
   B := not (I = 1);                       --  logical_not
   B := not B;                             --  fine
   B := B = True;                          --  logical_true
   B := B /= False;                        --  logical_false
   B := I = 1 or I = 2 or I = 3;           --  membership (in)
   B := I /= 1 and then I /= 2;            --  membership (not in)
   B := I = 1 or N = 2;                    --  fine: two variables
   for K in Small'First .. Small'Last loop --  range
      A (K) := 0;
   end loop;
   I := (I + 1);                           --  parentheses: a whole assignment
   I := I + (I * 2);                       --  parentheses: * binds more tightly
   I := I - (I - 1);                       --  fine: the same precedence
   I := (I + 1) * 2;                       --  fine: needed
   if (B) then                             --  parentheses: a whole condition
      I := 0;
   end if;
   I := (if not B then 1 else 2);          --  if_not; the parentheses are required
end Test;
