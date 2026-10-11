--  Subprogram metrics: statements and decisions count toward the innermost
--  subprogram only, not toward the ones around it.
procedure Test (N : Integer) is
   function Double (X : Integer) return Integer is (if X > 0 then 2 * X else 0);

   procedure Outer (B : Boolean) is
      procedure Inner is
      begin
         if B then
            null;
         end if;
      end Inner;
   begin
      Inner;
      while B loop
         exit when N > 1 or else N < 0;
      end loop;
   end Outer;

   procedure Choose (K : Integer) is
   begin
      case K is
         when 1 => null;
         when 2 => null;
         when others => null;
      end case;
   end Choose;
begin
   Outer (Double (N) > 0);
   Choose (N);
end Test;
