--  SSA conformance: in/in out/out parameter entry writes, the exit-read that
--  keeps an out/in-out parameter's last write alive, and out/in-out actuals
--  at a call site (uncertain writes, resolved by name for a named
--  association); `Y`, declared without a value, gets a value-less entry write.
--  See docs/ssa-design.md, "Parameters".
procedure Test is
   procedure Modify (A : in out Integer; B : out Integer) is
   begin
      A := A + 1;  -- $ ssa=def(A)@9:7|reads|exitSubpBody(normal)@7:4
      B := 0;  -- $ ssa=def(B)@10:7|reads|exitSubpBody(normal)@7:4
   end Modify;  -- $ ssa=def(A)@7:4|reads|Identifier@9:12

   X, Y : Integer;
begin
   X := 1;  -- $ ssa=def(X)@15:4|reads|Identifier@16:25
   Modify (B => Y, A => X);  -- $ ssa=def(X)@16:4|reads|Identifier@17:9
   Y := X;
end Test;  -- $ ssa=def(Y)@6:1|reads|Identifier@16:17
