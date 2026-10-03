--  CFG conformance: concatenation chains.
--  `A & B & C` is one ConcatOp: its first operand, then a ConcatOperandList
--  of ConcatOperands, each wrapping one further operand. Every operand is
--  evaluated, left to right, before the ConcatOp itself.
--  See docs/cfg-design.md, "Linear code".
function Concat (A, B, C : String) return String is
begin
   return A & B & C;  -- $ edge=ReturnStmt@8:4|return|exitSubpBody(normal)@6:1 edge=Identifier@8:11|successor|Identifier@8:15 edge=ConcatOp@8:11|successor|ReturnStmt@8:4 edge=ConcatOperand@8:13|successor|Identifier@8:19 edge=ConcatOperandList@8:13|successor|ConcatOp@8:11 edge=Identifier@8:15|successor|ConcatOperand@8:13 edge=ConcatOperand@8:17|successor|ConcatOperandList@8:13 edge=Identifier@8:19|successor|ConcatOperand@8:17
end Concat;  -- $ edge=enterSubpBody@6:1|successor|Identifier@8:11 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
