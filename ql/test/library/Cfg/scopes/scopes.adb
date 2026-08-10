--  CFG conformance: the five scope kinds, and elaboration of declarative parts.
--  See docs/cfg-design.md, "Scopes".
--
--  Each body is its own disconnected graph. With_Decl pins the fix for defect
--  C-1: the initialiser of Local is elaborated before the statements, so the
--  call to Double -- which can raise -- is in the graph. Before the fix, entry
--  jumped straight to the null statement and the call was invisible.
--
--  Wait's barrier is evaluated before the entry body is entered, so it is the
--  first node of that scope.
package body Scopes is

   function Double (X : Integer) return Integer is (X * 2);  -- $ edge=BinOp@13:53|successor|ParenExpr@13:52 edge=Identifier@13:53|successor|IntLiteral@13:57 edge=IntLiteral@13:57|successor|BinOp@13:53 edge=ParenExpr@13:52|successor|exitExprFunction(normal)@13:4 edge=enterExprFunction@13:4|successor|Identifier@13:53 edge=exitExprFunction(normal)@13:4|successor|exitExprFunction@13:4

   procedure With_Decl is
      Local : Integer := Double (1);  -- $ edge=AssocList@16:34|successor|CallExpr@16:26 edge=CallExpr@16:26|exception|exitSubpBody(abnormal)@15:4 edge=CallExpr@16:26|successor|NullStmt@18:7 edge=Identifier@16:26|successor|IntLiteral@16:34 edge=IntLiteral@16:34|successor|ParamAssoc@16:34 edge=ParamAssoc@16:34|successor|AssocList@16:34
   begin
      null;  -- $ edge=NullStmt@18:7|successor|exitSubpBody(normal)@15:4
   end With_Decl;  -- $ edge=enterSubpBody@15:4|successor|Identifier@16:26 edge=exitSubpBody(abnormal)@15:4|successor|exitSubpBody@15:4 edge=exitSubpBody(normal)@15:4|successor|exitSubpBody@15:4

   task body Worker is
   begin
      null;  -- $ edge=NullStmt@23:7|successor|exitTaskBody(normal)@21:4
   end Worker;  -- $ edge=enterTaskBody@21:4|successor|NullStmt@23:7 edge=exitTaskBody(normal)@21:4|successor|exitTaskBody@21:4

   protected body Guard is
      entry Wait when True is  -- $ edge=Identifier@27:23|successor|NullStmt@29:10
      begin
         null;  -- $ edge=NullStmt@29:10|successor|exitEntryBody(normal)@27:7
      end Wait;  -- $ edge=enterEntryBody@27:7|successor|Identifier@27:23 edge=exitEntryBody(normal)@27:7|successor|exitEntryBody@27:7
   end Guard;

begin
   null;  -- $ edge=NullStmt@34:4|successor|exitPackageBody(normal)@11:1
end Scopes;  -- $ edge=enterPackageBody@11:1|successor|NullStmt@34:4 edge=exitPackageBody(normal)@11:1|successor|exitPackageBody@11:1
