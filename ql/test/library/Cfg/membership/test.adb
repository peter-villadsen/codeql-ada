--  CFG conformance: membership tests.
--  `X in A | B` is a MembershipExpr: the tested expression, then an
--  ExprAlternativesList of the alternatives, all modelled as evaluated, left
--  to right (an over-approximation: Ada stops at the first that matches).
--  See docs/cfg-design.md, "Linear code".
function Membership (X, Y : Integer) return Boolean is
begin
   return X in 1 | Y;  -- $ edge=ExprAlternativesList@8:16|successor|after:ExprAlternativesList@8:16 edge=Identifier@8:11|successor|before:ExprAlternativesList@8:16 edge=Identifier@8:20|successor|ExprAlternativesList@8:16 edge=IntLiteral@8:16|successor|Identifier@8:20 edge=MembershipExpr@8:11|successor|after:MembershipExpr@8:11 edge=ReturnStmt@8:4|return|exitSubpBody(normal)@6:1 edge=StmtList@8:4|successor|before:ReturnStmt@8:4 edge=after:ExprAlternativesList@8:16|successor|MembershipExpr@8:11 edge=after:MembershipExpr@8:11|successor|ReturnStmt@8:4 edge=before:ExprAlternativesList@8:16|successor|IntLiteral@8:16 edge=before:MembershipExpr@8:11|successor|Identifier@8:11 edge=before:ReturnStmt@8:4|successor|before:MembershipExpr@8:11
end Membership;  -- $ edge=HandledStmts@7:6|successor|StmtList@8:4 edge=enterSubpBody@6:1|successor|HandledStmts@7:6 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
