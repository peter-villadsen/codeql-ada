--  SSA conformance: straight-line code, no branches or loops.
--  See docs/ssa-design.md, "Straight-line code".
procedure Test is
   X : Integer := 1;  -- $ ssa=def(X)@4:19|reads|Identifier@7:9
   Y : Integer;
begin
   Y := X;  -- $ ssa=def(Y)@7:4|reads|Identifier@8:9
   X := Y + 1;
end Test;
