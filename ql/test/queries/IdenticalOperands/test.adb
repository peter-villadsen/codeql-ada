function Check (X : Boolean) return Boolean;

procedure Test is
   A : Boolean := True;
   B : Boolean := True;
begin
   if A and A then              --  BAD
      null;
   end if;
   if A or else A then          --  BAD
      null;
   end if;
   if A xor A then              --  BAD
      null;
   end if;
   if A and B then               --  fine, different operands
      null;
   end if;
   if Check (A) and Check (A) then  --  fine, function results can differ
      null;
   end if;
end Test;
