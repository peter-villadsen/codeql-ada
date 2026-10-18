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

   function Double (X : Integer) return Integer is (X * 2);  -- $ edge=BinOp@13:53|successor|after:BinOp@13:53 edge=Identifier@13:53|successor|IntLiteral@13:57 edge=IntLiteral@13:57|successor|BinOp@13:53 edge=ParenExpr@13:52|successor|after:ParenExpr@13:52 edge=after:BinOp@13:53|successor|ParenExpr@13:52 edge=after:ParenExpr@13:52|successor|exitExprFunction(normal)@13:4 edge=before:BinOp@13:53|successor|Identifier@13:53 edge=before:ParenExpr@13:52|successor|before:BinOp@13:53 edge=enterExprFunction@13:4|successor|before:ParenExpr@13:52 edge=exitExprFunction(normal)@13:4|successor|exitExprFunction@13:4

   procedure With_Decl is
      Local : Integer := Double (1);  -- $ edge=AssocList@16:34|successor|after:AssocList@16:34 edge=CallExpr@16:26|exception|exitSubpBody(abnormal)@15:4 edge=CallExpr@16:26|successor|after:CallExpr@16:26 edge=Identifier@16:26|successor|before:AssocList@16:34 edge=IntLiteral@16:34|successor|ParamAssoc@16:34 edge=ParamAssoc@16:34|successor|after:ParamAssoc@16:34 edge=after:AssocList@16:34|successor|CallExpr@16:26 edge=after:CallExpr@16:26|successor|HandledStmts@17:9 edge=after:ParamAssoc@16:34|successor|AssocList@16:34 edge=before:AssocList@16:34|successor|before:ParamAssoc@16:34 edge=before:CallExpr@16:26|successor|Identifier@16:26 edge=before:ParamAssoc@16:34|successor|IntLiteral@16:34
   begin
      null;  -- $ edge=NullStmt@18:7|successor|after:StmtList@18:7 edge=StmtList@18:7|successor|NullStmt@18:7 edge=after:StmtList@18:7|successor|after:HandledStmts@17:9
   end With_Decl;  -- $ edge=HandledStmts@17:9|successor|StmtList@18:7 edge=after:HandledStmts@17:9|successor|exitSubpBody(normal)@15:4 edge=enterSubpBody@15:4|successor|before:CallExpr@16:26 edge=exitSubpBody(abnormal)@15:4|successor|exitSubpBody@15:4 edge=exitSubpBody(normal)@15:4|successor|exitSubpBody@15:4

   task body Worker is
   begin
      null;  -- $ edge=NullStmt@23:7|successor|after:StmtList@23:7 edge=StmtList@23:7|successor|NullStmt@23:7 edge=after:StmtList@23:7|successor|after:HandledStmts@22:9
   end Worker;  -- $ edge=HandledStmts@22:9|successor|StmtList@23:7 edge=after:HandledStmts@22:9|successor|exitTaskBody(normal)@21:4 edge=enterTaskBody@21:4|successor|HandledStmts@22:9 edge=exitTaskBody(normal)@21:4|successor|exitTaskBody@21:4

   protected body Guard is
      entry Wait when True is  -- $ edge=Identifier@27:23|successor|HandledStmts@28:12
      begin
         null;  -- $ edge=NullStmt@29:10|successor|after:StmtList@29:10 edge=StmtList@29:10|successor|NullStmt@29:10 edge=after:StmtList@29:10|successor|after:HandledStmts@28:12
      end Wait;  -- $ edge=HandledStmts@28:12|successor|StmtList@29:10 edge=after:HandledStmts@28:12|successor|exitEntryBody(normal)@27:7 edge=enterEntryBody@27:7|successor|Identifier@27:23 edge=exitEntryBody(normal)@27:7|successor|exitEntryBody@27:7
   end Guard;

begin
   null;  -- $ edge=NullStmt@34:4|successor|after:StmtList@34:4 edge=StmtList@34:4|successor|NullStmt@34:4 edge=after:StmtList@34:4|successor|after:HandledStmts@33:6
end Scopes;  -- $ edge=HandledStmts@33:6|successor|StmtList@34:4 edge=after:HandledStmts@33:6|successor|exitPackageBody(normal)@11:1 edge=enterPackageBody@11:1|successor|HandledStmts@33:6 edge=exitPackageBody(normal)@11:1|successor|exitPackageBody@11:1
