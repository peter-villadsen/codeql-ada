function Check (X : Boolean) return Boolean;

procedure Test is
   type Diff is record
      Added, Removed : Boolean;
   end record;
   A : Boolean := True;
   B : Boolean := True;
   C, D : Boolean := False;
   L, R : Diff;
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
   if C and then D then          --  fine, one declaration, two names (D-024)
      null;
   end if;
   if L.Added and then R.Added then     --  fine, different prefixes
      null;
   end if;
   if L.Added and then L.Removed then   --  fine, different components
      null;
   end if;
   if L.Added or L.Added then           --  BAD
      null;
   end if;
end Test;
