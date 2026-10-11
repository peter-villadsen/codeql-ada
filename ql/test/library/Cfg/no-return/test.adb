--  CFG conformance: calls to No_Return subprograms only raise.
--  Marked by aspect on the spec (called from the body, where the call may resolve
--  to the body), and by pragma. The statement after such a call is unreachable.
--  See docs/cfg-design.md, "Exceptions".
package body No_Return_Test is
   procedure Fail (Msg : String) is
   begin
      raise Program_Error with Msg;  -- $ edge=Identifier@8:13|successor|Identifier@8:32 edge=Identifier@8:32|successor|RaiseStmt@8:7 edge=RaiseStmt@8:7|exception|exitSubpBody(abnormal)@6:4
   end Fail;  -- $ edge=enterSubpBody@6:4|successor|Identifier@8:13 edge=exitSubpBody(abnormal)@6:4|successor|exitSubpBody@6:4

   procedure Stop;
   pragma No_Return (Stop);
   procedure Stop is
   begin
      raise Program_Error;  -- $ edge=Identifier@15:13|successor|RaiseStmt@15:7 edge=RaiseStmt@15:7|exception|exitSubpBody(abnormal)@13:4
   end Stop;  -- $ edge=enterSubpBody@13:4|successor|Identifier@15:13 edge=exitSubpBody(abnormal)@13:4|successor|exitSubpBody@13:4

   function F (B : Boolean) return Integer is
   begin
      if B then  -- $ edge=Identifier@20:10|false|IfStmt@20:7 edge=Identifier@20:10|true|IntLiteral@21:17
         return 1;  -- $ edge=IntLiteral@21:17|successor|ReturnStmt@21:10 edge=ReturnStmt@21:10|return|exitSubpBody(normal)@18:4
      end if;  -- $ edge=IfStmt@20:7|successor|Identifier@23:7
      Fail ("no");  -- $ edge=AssocList@23:13|successor|CallExpr@23:7 edge=CallExpr@23:7|exception|exitSubpBody(abnormal)@18:4 edge=Identifier@23:7|successor|StringLiteral@23:13 edge=ParamAssoc@23:13|successor|AssocList@23:13 edge=StringLiteral@23:13|successor|ParamAssoc@23:13
   end F;  -- $ edge=enterSubpBody@18:4|successor|Identifier@20:10 edge=exitSubpBody(abnormal)@18:4|successor|exitSubpBody@18:4 edge=exitSubpBody(normal)@18:4|successor|exitSubpBody@18:4

   procedure G is
   begin
      Stop;  -- $ edge=CallStmt@28:7|exception|exitSubpBody(abnormal)@26:4 edge=Identifier@28:7|successor|CallStmt@28:7
      null;
   end G;  -- $ edge=enterSubpBody@26:4|successor|Identifier@28:7 edge=exitSubpBody(abnormal)@26:4|successor|exitSubpBody@26:4
end No_Return_Test;
