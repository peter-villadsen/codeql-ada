--  SSA conformance: a phi at the loop header (the loop variable's node, where
--  each iteration starts), merging the initial value with the back edge.
--  See docs/ssa-design.md, "Loop".
procedure Test is
   Total : Integer := 0;  -- $ ssa=phi(Total)@7:8|from|def(Total)@5:23
begin
   for I in 1 .. 10 loop  -- $ ssa=def(I)@7:13|reads|Identifier@8:24 ssa=phi(Total)@7:8|reads|Identifier@8:16
      Total := Total + I;  -- $ ssa=phi(Total)@7:8|from|def(Total)@8:7
   end loop;
end Test;
