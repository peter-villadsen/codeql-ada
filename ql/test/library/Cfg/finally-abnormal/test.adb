--  CFG conformance: a GNAT `finally` part runs however its sequence is left -- by
--  `return`, by an `exit` from an enclosing loop, or by a raise no handler catches --
--  and afterwards continues the way it was entered. Each way in has its own copy of
--  the `finally` part's nodes (a split), so the copy entered by `return` can only
--  return. A `goto` out of the sequence does not run it.
--  See docs/cfg-design.md, "Finally parts".
pragma Extensions_Allowed (All_Extensions);
procedure Test is
   procedure P is null;
   X : Integer := 0;  -- $ edge=IntLiteral@10:19|successor|NullStmt@76:4

   procedure Returns (B : Boolean) is
   begin
      begin
         if B then  -- $ edge=Identifier@15:13|false|IfStmt@15:10 edge=Identifier@15:13|true|ReturnStmt@16:13
            return;  -- $ edge=ReturnStmt@16:13|return|[finally:return]IntLiteral@20:15
         end if;  -- $ edge=IfStmt@15:10|successor|IntLiteral@18:15
         X := 1;  -- $ edge=AssignStmt@18:10|successor|IntLiteral@20:15 edge=Identifier@18:10|successor|AssignStmt@18:10 edge=IntLiteral@18:15|successor|Identifier@18:10
      finally
         X := 2;  -- $ edge=AssignStmt@20:10|successor|IntLiteral@22:12 edge=Identifier@20:10|successor|AssignStmt@20:10 edge=IntLiteral@20:15|successor|Identifier@20:10 edge=[finally:return]AssignStmt@20:10|return|exitSubpBody(normal)@12:4 edge=[finally:return]Identifier@20:10|successor|[finally:return]AssignStmt@20:10 edge=[finally:return]IntLiteral@20:15|successor|[finally:return]Identifier@20:10
      end;
      X := 3;  -- $ edge=AssignStmt@22:7|successor|exitSubpBody(normal)@12:4 edge=Identifier@22:7|successor|AssignStmt@22:7 edge=IntLiteral@22:12|successor|Identifier@22:7
   end Returns;  -- $ edge=enterSubpBody@12:4|successor|Identifier@15:13 edge=exitSubpBody(normal)@12:4|successor|exitSubpBody@12:4

   procedure Exits is
   begin
      Outer : loop
         loop
            begin
               exit Outer when X > 0;  -- $ edge=ExitStmt@30:16|break|[finally:exit@27]IntLiteral@33:21 edge=Identifier@30:32|successor|IntLiteral@30:36 edge=IntLiteral@30:36|successor|RelationOp@30:32 edge=RelationOp@30:32|false|ExitStmt@31:16 edge=RelationOp@30:32|true|ExitStmt@30:16
               exit;  -- $ edge=ExitStmt@31:16|break|[finally:exit@28]IntLiteral@33:21
            finally
               X := 4;  -- $ edge=[finally:exit@27]AssignStmt@33:16|break|LoopStmt@27:15 edge=[finally:exit@27]Identifier@33:16|successor|[finally:exit@27]AssignStmt@33:16 edge=[finally:exit@27]IntLiteral@33:21|successor|[finally:exit@27]Identifier@33:16 edge=[finally:exit@28]AssignStmt@33:16|break|LoopStmt@28:10 edge=[finally:exit@28]Identifier@33:16|successor|[finally:exit@28]AssignStmt@33:16 edge=[finally:exit@28]IntLiteral@33:21|successor|[finally:exit@28]Identifier@33:16
            end;
         end loop;  -- $ edge=LoopStmt@28:10|successor|IntLiteral@36:15
         X := 5;  -- $ edge=AssignStmt@36:10|successor|Identifier@30:32 edge=Identifier@36:10|successor|AssignStmt@36:10 edge=IntLiteral@36:15|successor|Identifier@36:10
      end loop Outer;  -- $ edge=LoopStmt@27:15|successor|IntLiteral@38:12
      X := 6;  -- $ edge=AssignStmt@38:7|successor|exitSubpBody(normal)@25:4 edge=Identifier@38:7|successor|AssignStmt@38:7 edge=IntLiteral@38:12|successor|Identifier@38:7
   end Exits;  -- $ edge=enterSubpBody@25:4|successor|Identifier@30:32 edge=exitSubpBody(normal)@25:4|successor|exitSubpBody@25:4

   procedure Raises is
   begin
      begin
         P;  -- $ edge=CallStmt@44:10|exception|IntLiteral@47:18 edge=CallStmt@44:10|exception|[finally:raise]IntLiteral@49:15 edge=CallStmt@44:10|successor|IntLiteral@49:15 edge=Identifier@44:10|successor|CallStmt@44:10
      exception
         when Constraint_Error =>
            X := 7;  -- $ edge=AssignStmt@47:13|successor|IntLiteral@49:15 edge=Identifier@47:13|successor|AssignStmt@47:13 edge=IntLiteral@47:18|successor|Identifier@47:13
      finally
         X := 8;  -- $ edge=AssignStmt@49:10|successor|exitSubpBody(normal)@41:4 edge=Identifier@49:10|successor|AssignStmt@49:10 edge=IntLiteral@49:15|successor|Identifier@49:10 edge=[finally:raise]AssignStmt@49:10|exception|exitSubpBody(abnormal)@41:4 edge=[finally:raise]Identifier@49:10|successor|[finally:raise]AssignStmt@49:10 edge=[finally:raise]IntLiteral@49:15|successor|[finally:raise]Identifier@49:10
      end;
   end Raises;  -- $ edge=enterSubpBody@41:4|successor|Identifier@44:10 edge=exitSubpBody(abnormal)@41:4|successor|exitSubpBody@41:4 edge=exitSubpBody(normal)@41:4|successor|exitSubpBody@41:4

   procedure Nested is
   begin
      begin
         begin
            return;  -- $ edge=ReturnStmt@57:13|return|[finally:return]IntLiteral@59:18
         finally
            X := 9;  -- $ edge=[finally:return]AssignStmt@59:13|return|[finally:return]IntLiteral@62:15 edge=[finally:return]Identifier@59:13|successor|[finally:return]AssignStmt@59:13 edge=[finally:return]IntLiteral@59:18|successor|[finally:return]Identifier@59:13
         end;
      finally
         X := 10;  -- $ edge=[finally:return]AssignStmt@62:10|return|exitSubpBody(normal)@53:4 edge=[finally:return]Identifier@62:10|successor|[finally:return]AssignStmt@62:10 edge=[finally:return]IntLiteral@62:15|successor|[finally:return]Identifier@62:10
      end;
   end Nested;  -- $ edge=enterSubpBody@53:4|successor|ReturnStmt@57:13 edge=exitSubpBody(normal)@53:4|successor|exitSubpBody@53:4

   procedure Jumps is
   begin
      begin
         goto Done;  -- $ edge=GotoStmt@69:10|goto|Label@73:7
      finally
         X := 11;
      end;
      <<Done>> X := 12;  -- $ edge=AssignStmt@73:16|successor|exitSubpBody(normal)@66:4 edge=Identifier@73:16|successor|AssignStmt@73:16 edge=IntLiteral@73:21|successor|Identifier@73:16 edge=Label@73:7|successor|IntLiteral@73:21
   end Jumps;  -- $ edge=enterSubpBody@66:4|successor|GotoStmt@69:10 edge=exitSubpBody(normal)@66:4|successor|exitSubpBody@66:4
begin
   null;  -- $ edge=NullStmt@76:4|successor|exitSubpBody(normal)@8:1
end Test;  -- $ edge=enterSubpBody@8:1|successor|IntLiteral@10:19 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
