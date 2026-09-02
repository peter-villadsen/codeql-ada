--  SSA conformance: a phi node at a loop header, merging the initial value
--  with the back edge.
--  See docs/ssa-design.md, "Loop".
procedure Test is
   Total : Integer := 0;  -- $ ssa=phi(Total)@8:16|from|def(Total)@5:23
begin
   for I in 1 .. 10 loop  -- $ ssa=def(I)@7:13|reads|Identifier@8:24
      Total := Total + I;  -- $ ssa=phi(Total)@8:16|from|def(Total)@8:7 ssa=phi(Total)@8:16|reads|Identifier@8:16
   end loop;
end Test;
