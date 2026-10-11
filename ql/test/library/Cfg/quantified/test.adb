--  CFG conformance: a quantified expression evaluates what it iterates over, then
--  its predicate (once, standing for every iteration), then itself; the message of
--  `raise E with Msg` is evaluated before the raise.
--  See docs/cfg-design.md, "Quantified expressions and raise messages".
procedure Test is
   function F (X : Integer) return Boolean is (X > 0);  -- $ edge=Identifier@6:48|successor|IntLiteral@6:52 edge=IntLiteral@6:52|successor|RelationOp@6:48 edge=ParenExpr@6:47|successor|exitExprFunction(normal)@6:4 edge=RelationOp@6:48|successor|ParenExpr@6:47 edge=enterExprFunction@6:4|successor|Identifier@6:48 edge=exitExprFunction(normal)@6:4|successor|exitExprFunction@6:4
   function Msg return String is ("m");  -- $ edge=ParenExpr@7:34|successor|exitExprFunction(normal)@7:4 edge=StringLiteral@7:35|successor|ParenExpr@7:34 edge=enterExprFunction@7:4|successor|StringLiteral@7:35 edge=exitExprFunction(normal)@7:4|successor|exitExprFunction@7:4
   type Arr is array (1 .. 3) of Integer;
   V : constant Arr := (others => 1);  -- $ edge=Aggregate@9:24|successor|Identifier@12:23 edge=AggregateAssoc@9:25|successor|AssocList@9:25 edge=AssocList@9:25|successor|Aggregate@9:24 edge=IntLiteral@9:35|successor|AggregateAssoc@9:25
   B : Boolean;
begin
   B := (for all E of V => F (E));  -- $ edge=AssignStmt@12:4|successor|Identifier@13:11 edge=AssocList@12:31|successor|CallExpr@12:28 edge=CallExpr@12:28|exception|exitSubpBody(abnormal)@5:1 edge=CallExpr@12:28|successor|QuantifiedExpr@12:10 edge=Identifier@12:23|successor|Identifier@12:28 edge=Identifier@12:28|successor|Identifier@12:31 edge=Identifier@12:31|successor|ParamAssoc@12:31 edge=Identifier@12:4|successor|AssignStmt@12:4 edge=ParamAssoc@12:31|successor|AssocList@12:31 edge=ParenExpr@12:9|successor|Identifier@12:4 edge=QuantifiedExpr@12:10|successor|ParenExpr@12:9
   if not B then  -- $ edge=Identifier@13:11|successor|UnOp@13:7 edge=UnOp@13:7|false|IfStmt@13:4 edge=UnOp@13:7|true|Identifier@14:13
      raise Program_Error with Msg;  -- $ edge=Identifier@14:13|successor|Identifier@14:32 edge=Identifier@14:32|exception|exitSubpBody(abnormal)@5:1 edge=Identifier@14:32|successor|RaiseStmt@14:7 edge=RaiseStmt@14:7|exception|exitSubpBody(abnormal)@5:1
   end if;  -- $ edge=IfStmt@13:4|successor|exitSubpBody(normal)@5:1
end Test;  -- $ edge=enterSubpBody@5:1|successor|IntLiteral@9:35 edge=exitSubpBody(abnormal)@5:1|successor|exitSubpBody@5:1 edge=exitSubpBody(normal)@5:1|successor|exitSubpBody@5:1
