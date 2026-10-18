--  The class-based SSA API (`codeql.ada.dataflow.Ssa`): one definition of each
--  kind, with the write, value and parameter each one reports.
procedure Test is
   procedure Modify (A : in out Integer; B : out Integer) is
   begin
      A := A + 1;
      B := A;
   end Modify;

   function Sum (N : Integer) return Integer is
      Total : Integer := 0;
      R : Integer;
   begin
      for I in 1 .. N loop
         Total := Total + I;
      end loop;
      R := Total;
      return R;
   end Sum;

   X : Integer := 1;
   Y : Integer;
begin
   if X > 0 then
      X := 2;
   end if;
   Modify (X, Y);
   Y := Sum (X + Y);
end Test;
