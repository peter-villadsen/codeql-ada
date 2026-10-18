--  CFG conformance: calls to No_Return subprograms only raise.
--  Marked by aspect on the spec (called from the body, where the call may resolve
--  to the body), and by pragma. The statement after such a call is unreachable.
--  See docs/cfg-design.md, "Exceptions".
package body No_Return_Test is
   procedure Fail (Msg : String) is
   begin
      raise Program_Error with Msg;  -- $ edge=Identifier@8:13|successor|Identifier@8:32 edge=Identifier@8:32|successor|RaiseStmt@8:7 edge=RaiseStmt@8:7|exception|exitSubpBody(abnormal)@6:4 edge=StmtList@8:7|successor|before:RaiseStmt@8:7 edge=before:RaiseStmt@8:7|successor|Identifier@8:13
   end Fail;  -- $ edge=HandledStmts@7:9|successor|StmtList@8:7 edge=enterSubpBody@6:4|successor|HandledStmts@7:9 edge=exitSubpBody(abnormal)@6:4|successor|exitSubpBody@6:4

   procedure Stop;
   pragma No_Return (Stop);
   procedure Stop is
   begin
      raise Program_Error;  -- $ edge=Identifier@15:13|successor|RaiseStmt@15:7 edge=RaiseStmt@15:7|exception|exitSubpBody(abnormal)@13:4 edge=StmtList@15:7|successor|before:RaiseStmt@15:7 edge=before:RaiseStmt@15:7|successor|Identifier@15:13
   end Stop;  -- $ edge=HandledStmts@14:9|successor|StmtList@15:7 edge=enterSubpBody@13:4|successor|HandledStmts@14:9 edge=exitSubpBody(abnormal)@13:4|successor|exitSubpBody@13:4

   function F (B : Boolean) return Integer is
   begin
      if B then  -- $ edge=Identifier@20:10|false|after-false:Identifier@20:10 edge=Identifier@20:10|true|after-true:Identifier@20:10 edge=after-false:Identifier@20:10|successor|after:IfStmt@20:7 edge=after-true:Identifier@20:10|successor|StmtList@21:10
         return 1;  -- $ edge=IntLiteral@21:17|successor|ReturnStmt@21:10 edge=ReturnStmt@21:10|return|exitSubpBody(normal)@18:4 edge=StmtList@21:10|successor|before:ReturnStmt@21:10 edge=before:ReturnStmt@21:10|successor|IntLiteral@21:17
      end if;  -- $ edge=IfStmt@20:7|successor|Identifier@20:10 edge=after:IfStmt@20:7|successor|before:CallStmt@23:7
      Fail ("no");  -- $ edge=AssocList@23:13|successor|after:AssocList@23:13 edge=CallExpr@23:7|exception|exitSubpBody(abnormal)@18:4 edge=Identifier@23:7|successor|before:AssocList@23:13 edge=ParamAssoc@23:13|successor|after:ParamAssoc@23:13 edge=StmtList@20:7|successor|IfStmt@20:7 edge=StringLiteral@23:13|successor|ParamAssoc@23:13 edge=after:AssocList@23:13|successor|CallExpr@23:7 edge=after:ParamAssoc@23:13|successor|AssocList@23:13 edge=before:AssocList@23:13|successor|before:ParamAssoc@23:13 edge=before:CallExpr@23:7|successor|Identifier@23:7 edge=before:CallStmt@23:7|successor|before:CallExpr@23:7 edge=before:ParamAssoc@23:13|successor|StringLiteral@23:13
   end F;  -- $ edge=HandledStmts@19:9|successor|StmtList@20:7 edge=enterSubpBody@18:4|successor|HandledStmts@19:9 edge=exitSubpBody(abnormal)@18:4|successor|exitSubpBody@18:4 edge=exitSubpBody(normal)@18:4|successor|exitSubpBody@18:4

   procedure G is
   begin
      Stop;  -- $ edge=CallStmt@28:7|exception|exitSubpBody(abnormal)@26:4 edge=Identifier@28:7|successor|CallStmt@28:7 edge=before:CallStmt@28:7|successor|Identifier@28:7
      null;  -- $ edge=StmtList@28:7|successor|before:CallStmt@28:7
   end G;  -- $ edge=HandledStmts@27:9|successor|StmtList@28:7 edge=enterSubpBody@26:4|successor|HandledStmts@27:9 edge=exitSubpBody(abnormal)@26:4|successor|exitSubpBody@26:4
end No_Return_Test;
