--  CFG conformance: membership tests.
--  `X in A | B` is a MembershipExpr: the tested expression, then an
--  ExprAlternativesList of the alternatives, all modelled as evaluated, left
--  to right (an over-approximation: Ada stops at the first that matches).
--  See docs/cfg-design.md, "Linear code".
function Membership (X, Y : Integer) return Boolean is
begin
   return X in 1 | Y;  -- $ edge=ReturnStmt@8:4|return|exitSubpBody(normal)@6:1 edge=Identifier@8:11|successor|IntLiteral@8:16 edge=MembershipExpr@8:11|successor|ReturnStmt@8:4 edge=IntLiteral@8:16|successor|Identifier@8:20 edge=ExprAlternativesList@8:16|successor|MembershipExpr@8:11 edge=Identifier@8:20|successor|ExprAlternativesList@8:16
end Membership;  -- $ edge=enterSubpBody@6:1|successor|Identifier@8:11 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
