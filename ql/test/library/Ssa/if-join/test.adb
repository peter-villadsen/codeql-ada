--  SSA conformance: a phi node at an if/else join.
--  See docs/ssa-design.md, "Branch join".
procedure Test is
   X : Integer;
begin
   if True then
      X := 1;  -- $ ssa=phi(X)@6:4|from|def(X)@7:7
   else
      X := 2;  -- $ ssa=phi(X)@6:4|from|def(X)@9:7
   end if;  -- $ ssa=phi(X)@6:4|reads|Identifier@11:9
   X := X + 1;
end Test;
