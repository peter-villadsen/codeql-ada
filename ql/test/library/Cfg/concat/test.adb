--  CFG conformance: concatenation chains.
--  `A & B & C` is one ConcatOp: its first operand, then a ConcatOperandList
--  of ConcatOperands, each wrapping one further operand. Every operand is
--  evaluated, left to right, before the ConcatOp itself.
--  See docs/cfg-design.md, "Linear code".
function Concat (A, B, C : String) return String is
begin
   return A & B & C;  -- $ edge=ConcatOp@8:11|successor|after:ConcatOp@8:11 edge=ConcatOperand@8:13|successor|after:ConcatOperand@8:13 edge=ConcatOperand@8:17|successor|after:ConcatOperand@8:17 edge=ConcatOperandList@8:13|successor|after:ConcatOperandList@8:13 edge=Identifier@8:11|successor|before:ConcatOperandList@8:13 edge=Identifier@8:15|successor|ConcatOperand@8:13 edge=Identifier@8:19|successor|ConcatOperand@8:17 edge=ReturnStmt@8:4|return|exitSubpBody(normal)@6:1 edge=StmtList@8:4|successor|before:ReturnStmt@8:4 edge=after:ConcatOp@8:11|successor|ReturnStmt@8:4 edge=after:ConcatOperand@8:13|successor|before:ConcatOperand@8:17 edge=after:ConcatOperand@8:17|successor|ConcatOperandList@8:13 edge=after:ConcatOperandList@8:13|successor|ConcatOp@8:11 edge=before:ConcatOp@8:11|successor|Identifier@8:11 edge=before:ConcatOperand@8:13|successor|Identifier@8:15 edge=before:ConcatOperand@8:17|successor|Identifier@8:19 edge=before:ConcatOperandList@8:13|successor|before:ConcatOperand@8:13 edge=before:ReturnStmt@8:4|successor|before:ConcatOp@8:11
end Concat;  -- $ edge=HandledStmts@7:6|successor|StmtList@8:4 edge=enterSubpBody@6:1|successor|HandledStmts@7:6 edge=exitSubpBody(normal)@6:1|successor|exitSubpBody@6:1
