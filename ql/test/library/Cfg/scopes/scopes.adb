package body Scopes is

   function Double (X : Integer) return Integer is (X * 2);  -- $ edge=BinOp@3:53|successor|ParenExpr@3:52 edge=Identifier@3:53|successor|IntLiteral@3:57 edge=IntLiteral@3:57|successor|BinOp@3:53 edge=ParenExpr@3:52|successor|exitExprFunction(normal)@3:4 edge=enterExprFunction@3:4|successor|Identifier@3:53 edge=exitExprFunction(normal)@3:4|successor|exitExprFunction@3:4

   procedure With_Decl is
      Local : Integer := Double (1);  -- $ MISSING: edge=Identifier@6:26|successor|IntLiteral@6:34 edge=IntLiteral@6:34|successor|ParamAssoc@6:34 edge=ParamAssoc@6:34|successor|AssocList@6:34 edge=AssocList@6:34|successor|CallExpr@6:26 edge=CallExpr@6:26|successor|NullStmt@8:7 edge=CallExpr@6:26|exception|exitSubpBody(abnormal)@5:4
   begin
      null;  -- $ edge=NullStmt@8:7|successor|exitSubpBody(normal)@5:4
   end With_Decl;  -- $ edge=exitSubpBody(normal)@5:4|successor|exitSubpBody@5:4 SPURIOUS: edge=enterSubpBody@5:4|successor|NullStmt@8:7 MISSING: edge=enterSubpBody@5:4|successor|Identifier@6:26 edge=exitSubpBody(abnormal)@5:4|successor|exitSubpBody@5:4

   task body Worker is
   begin
      null;  -- $ edge=NullStmt@13:7|successor|exitTaskBody(normal)@11:4
   end Worker;  -- $ edge=enterTaskBody@11:4|successor|NullStmt@13:7 edge=exitTaskBody(normal)@11:4|successor|exitTaskBody@11:4

   protected body Guard is
      entry Wait when True is
      begin
         null;  -- $ edge=NullStmt@19:10|successor|exitEntryBody(normal)@17:7
      end Wait;  -- $ edge=enterEntryBody@17:7|successor|NullStmt@19:10 edge=exitEntryBody(normal)@17:7|successor|exitEntryBody@17:7
   end Guard;

begin
   null;  -- $ edge=NullStmt@24:4|successor|exitPackageBody(normal)@1:1
end Scopes;  -- $ edge=enterPackageBody@1:1|successor|NullStmt@24:4 edge=exitPackageBody(normal)@1:1|successor|exitPackageBody@1:1
