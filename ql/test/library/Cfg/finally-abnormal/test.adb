--  CFG conformance: a GNAT `finally` part runs however its sequence is left -- by
--  `return`, by an `exit` from an enclosing loop, by a raise no handler catches, or
--  by a `goto` -- and afterwards may continue every way it was entered: the graph
--  does not split it. Queries that need to tell the ways apart use
--  ControlFlowReachability.
--  See docs/cfg-design.md, "Finally parts".
pragma Extensions_Allowed (All_Extensions);
procedure Test is
   procedure P is null;
   X : Integer := 0;  -- $ edge=IntLiteral@10:19|successor|HandledStmts@75:6

   procedure Returns (B : Boolean) is
   begin
      begin
         if B then  -- $ edge=Identifier@15:13|false|after-false:Identifier@15:13 edge=Identifier@15:13|true|after-true:Identifier@15:13 edge=after-false:Identifier@15:13|successor|after:IfStmt@15:10 edge=after-true:Identifier@15:13|successor|StmtList@16:13
            return;  -- $ edge=ReturnStmt@16:13|return|StmtList@20:10 edge=StmtList@16:13|successor|before:ReturnStmt@16:13 edge=before:ReturnStmt@16:13|successor|ReturnStmt@16:13
         end if;  -- $ edge=IfStmt@15:10|successor|Identifier@15:13 edge=after:IfStmt@15:10|successor|before:AssignStmt@18:10
         X := 1;  -- $ edge=AssignStmt@18:10|successor|after:AssignStmt@18:10 edge=Identifier@18:10|successor|AssignStmt@18:10 edge=IntLiteral@18:15|successor|Identifier@18:10 edge=StmtList@15:10|successor|IfStmt@15:10 edge=after:AssignStmt@18:10|successor|after:StmtList@15:10 edge=after:StmtList@15:10|successor|StmtList@20:10 edge=before:AssignStmt@18:10|successor|IntLiteral@18:15
      finally
         X := 2;  -- $ edge=AssignStmt@20:10|successor|after:AssignStmt@20:10 edge=Identifier@20:10|successor|AssignStmt@20:10 edge=IntLiteral@20:15|successor|Identifier@20:10 edge=StmtList@20:10|successor|before:AssignStmt@20:10 edge=after:AssignStmt@20:10|successor|after:StmtList@20:10 edge=after:StmtList@20:10|return|exitSubpBody(normal)@12:4 edge=after:StmtList@20:10|successor|after:HandledStmts@14:12 edge=before:AssignStmt@20:10|successor|IntLiteral@20:15
      end;  -- $ edge=BeginBlock@14:7|successor|HandledStmts@14:12 edge=HandledStmts@14:12|successor|StmtList@15:10 edge=after:BeginBlock@14:7|successor|before:AssignStmt@22:7 edge=after:HandledStmts@14:12|successor|after:BeginBlock@14:7
      X := 3;  -- $ edge=AssignStmt@22:7|successor|after:AssignStmt@22:7 edge=Identifier@22:7|successor|AssignStmt@22:7 edge=IntLiteral@22:12|successor|Identifier@22:7 edge=StmtList@14:7|successor|BeginBlock@14:7 edge=after:AssignStmt@22:7|successor|after:StmtList@14:7 edge=after:StmtList@14:7|successor|after:HandledStmts@13:9 edge=before:AssignStmt@22:7|successor|IntLiteral@22:12
   end Returns;  -- $ edge=HandledStmts@13:9|successor|StmtList@14:7 edge=after:HandledStmts@13:9|successor|exitSubpBody(normal)@12:4 edge=enterSubpBody@12:4|successor|HandledStmts@13:9 edge=exitSubpBody(normal)@12:4|successor|exitSubpBody@12:4

   procedure Exits is
   begin
      Outer : loop
         loop
            begin
               exit Outer when X > 0;  -- $ edge=ExitStmt@30:16|break|StmtList@33:16 edge=Identifier@30:32|successor|IntLiteral@30:36 edge=IntLiteral@30:36|successor|RelationOp@30:32 edge=RelationOp@30:32|false|after-false:RelationOp@30:32 edge=RelationOp@30:32|true|after-true:RelationOp@30:32 edge=after-false:RelationOp@30:32|successor|after:ExitStmt@30:16 edge=after-true:RelationOp@30:32|successor|ExitStmt@30:16 edge=after:ExitStmt@30:16|successor|before:ExitStmt@31:16 edge=before:ExitStmt@30:16|successor|before:RelationOp@30:32 edge=before:RelationOp@30:32|successor|Identifier@30:32
               exit;  -- $ edge=ExitStmt@31:16|break|StmtList@33:16 edge=StmtList@30:16|successor|before:ExitStmt@30:16 edge=before:ExitStmt@31:16|successor|ExitStmt@31:16
            finally
               X := 4;  -- $ edge=AssignStmt@33:16|successor|after:AssignStmt@33:16 edge=Identifier@33:16|successor|AssignStmt@33:16 edge=IntLiteral@33:21|successor|Identifier@33:16 edge=StmtList@33:16|successor|before:AssignStmt@33:16 edge=after:AssignStmt@33:16|successor|after:StmtList@33:16 edge=after:StmtList@33:16|break|after:LoopStmt@27:15 edge=after:StmtList@33:16|break|after:LoopStmt@28:10 edge=before:AssignStmt@33:16|successor|IntLiteral@33:21
            end;  -- $ edge=BeginBlock@29:13|successor|HandledStmts@29:18 edge=HandledStmts@29:18|successor|StmtList@30:16 edge=StmtList@29:13|successor|BeginBlock@29:13
         end loop;  -- $ edge=LoopStmt@28:10|successor|add.[LoopHeader]:LoopStmt@28:10 edge=add.[LoopHeader]:LoopStmt@28:10|successor|StmtList@29:13 edge=after:LoopStmt@28:10|successor|before:AssignStmt@36:10
         X := 5;  -- $ edge=AssignStmt@36:10|successor|after:AssignStmt@36:10 edge=Identifier@36:10|successor|AssignStmt@36:10 edge=IntLiteral@36:15|successor|Identifier@36:10 edge=StmtList@28:10|successor|LoopStmt@28:10 edge=after:AssignStmt@36:10|successor|after:StmtList@28:10 edge=after:StmtList@28:10|successor|add.[LoopHeader]:LoopStmt@27:15 edge=before:AssignStmt@36:10|successor|IntLiteral@36:15
      end loop Outer;  -- $ edge=LoopStmt@27:15|successor|add.[LoopHeader]:LoopStmt@27:15 edge=NamedStmt@27:7|successor|LoopStmt@27:15 edge=add.[LoopHeader]:LoopStmt@27:15|successor|StmtList@28:10 edge=after:LoopStmt@27:15|successor|after:NamedStmt@27:7 edge=after:NamedStmt@27:7|successor|before:AssignStmt@38:7
      X := 6;  -- $ edge=AssignStmt@38:7|successor|after:AssignStmt@38:7 edge=Identifier@38:7|successor|AssignStmt@38:7 edge=IntLiteral@38:12|successor|Identifier@38:7 edge=StmtList@27:7|successor|NamedStmt@27:7 edge=after:AssignStmt@38:7|successor|after:StmtList@27:7 edge=after:StmtList@27:7|successor|after:HandledStmts@26:9 edge=before:AssignStmt@38:7|successor|IntLiteral@38:12
   end Exits;  -- $ edge=HandledStmts@26:9|successor|StmtList@27:7 edge=after:HandledStmts@26:9|successor|exitSubpBody(normal)@25:4 edge=enterSubpBody@25:4|successor|HandledStmts@26:9 edge=exitSubpBody(normal)@25:4|successor|exitSubpBody@25:4

   procedure Raises is
   begin
      begin
         P;  -- $ edge=CallStmt@44:10|exception|ExceptionHandler@46:10 edge=CallStmt@44:10|successor|after:CallStmt@44:10 edge=Identifier@44:10|successor|CallStmt@44:10 edge=StmtList@44:10|successor|before:CallStmt@44:10 edge=after:CallStmt@44:10|successor|after:StmtList@44:10 edge=after:StmtList@44:10|successor|StmtList@49:10 edge=before:CallStmt@44:10|successor|Identifier@44:10
      exception
         when Constraint_Error =>
            X := 7;  -- $ edge=AssignStmt@47:13|successor|after:AssignStmt@47:13 edge=ExceptionHandler@46:10|match|after-true:ExceptionHandler@46:10 edge=ExceptionHandler@46:10|no-match|after-false:ExceptionHandler@46:10 edge=Identifier@47:13|successor|AssignStmt@47:13 edge=IntLiteral@47:18|successor|Identifier@47:13 edge=StmtList@47:13|successor|before:AssignStmt@47:13 edge=after-false:ExceptionHandler@46:10|exception|StmtList@49:10 edge=after-true:ExceptionHandler@46:10|successor|StmtList@47:13 edge=after:AssignStmt@47:13|successor|after:StmtList@47:13 edge=after:StmtList@47:13|successor|StmtList@49:10 edge=before:AssignStmt@47:13|successor|IntLiteral@47:18
      finally
         X := 8;  -- $ edge=AssignStmt@49:10|successor|after:AssignStmt@49:10 edge=Identifier@49:10|successor|AssignStmt@49:10 edge=IntLiteral@49:15|successor|Identifier@49:10 edge=StmtList@49:10|successor|before:AssignStmt@49:10 edge=after:AssignStmt@49:10|successor|after:StmtList@49:10 edge=after:StmtList@49:10|exception|exitSubpBody(abnormal)@41:4 edge=after:StmtList@49:10|successor|after:HandledStmts@43:12 edge=before:AssignStmt@49:10|successor|IntLiteral@49:15
      end;  -- $ edge=BeginBlock@43:7|successor|HandledStmts@43:12 edge=HandledStmts@43:12|successor|StmtList@44:10 edge=StmtList@43:7|successor|BeginBlock@43:7 edge=after:BeginBlock@43:7|successor|after:StmtList@43:7 edge=after:HandledStmts@43:12|successor|after:BeginBlock@43:7 edge=after:StmtList@43:7|successor|after:HandledStmts@42:9
   end Raises;  -- $ edge=HandledStmts@42:9|successor|StmtList@43:7 edge=after:HandledStmts@42:9|successor|exitSubpBody(normal)@41:4 edge=enterSubpBody@41:4|successor|HandledStmts@42:9 edge=exitSubpBody(abnormal)@41:4|successor|exitSubpBody@41:4 edge=exitSubpBody(normal)@41:4|successor|exitSubpBody@41:4

   procedure Nested is
   begin
      begin
         begin
            return;  -- $ edge=ReturnStmt@57:13|return|StmtList@59:13 edge=StmtList@57:13|successor|before:ReturnStmt@57:13 edge=before:ReturnStmt@57:13|successor|ReturnStmt@57:13
         finally
            X := 9;  -- $ edge=AssignStmt@59:13|successor|after:AssignStmt@59:13 edge=Identifier@59:13|successor|AssignStmt@59:13 edge=IntLiteral@59:18|successor|Identifier@59:13 edge=StmtList@59:13|successor|before:AssignStmt@59:13 edge=after:AssignStmt@59:13|successor|after:StmtList@59:13 edge=after:StmtList@59:13|return|StmtList@62:10 edge=before:AssignStmt@59:13|successor|IntLiteral@59:18
         end;  -- $ edge=BeginBlock@56:10|successor|HandledStmts@56:15 edge=HandledStmts@56:15|successor|StmtList@57:13 edge=StmtList@56:10|successor|BeginBlock@56:10
      finally
         X := 10;  -- $ edge=AssignStmt@62:10|successor|after:AssignStmt@62:10 edge=Identifier@62:10|successor|AssignStmt@62:10 edge=IntLiteral@62:15|successor|Identifier@62:10 edge=StmtList@62:10|successor|before:AssignStmt@62:10 edge=after:AssignStmt@62:10|successor|after:StmtList@62:10 edge=after:StmtList@62:10|return|exitSubpBody(normal)@53:4 edge=after:StmtList@62:10|successor|after:HandledStmts@55:12 edge=before:AssignStmt@62:10|successor|IntLiteral@62:15
      end;  -- $ edge=BeginBlock@55:7|successor|HandledStmts@55:12 edge=HandledStmts@55:12|successor|StmtList@56:10 edge=StmtList@55:7|successor|BeginBlock@55:7 edge=after:BeginBlock@55:7|successor|after:StmtList@55:7 edge=after:HandledStmts@55:12|successor|after:BeginBlock@55:7 edge=after:StmtList@55:7|successor|after:HandledStmts@54:9
   end Nested;  -- $ edge=HandledStmts@54:9|successor|StmtList@55:7 edge=after:HandledStmts@54:9|successor|exitSubpBody(normal)@53:4 edge=enterSubpBody@53:4|successor|HandledStmts@54:9 edge=exitSubpBody(normal)@53:4|successor|exitSubpBody@53:4

   procedure Jumps is
   begin
      begin
         goto Done;  -- $ edge=GotoStmt@69:10|goto|StmtList@71:10 edge=StmtList@69:10|successor|before:GotoStmt@69:10 edge=before:GotoStmt@69:10|successor|GotoStmt@69:10
      finally
         X := 11;  -- $ edge=AssignStmt@71:10|successor|after:AssignStmt@71:10 edge=Identifier@71:10|successor|AssignStmt@71:10 edge=IntLiteral@71:15|successor|Identifier@71:10 edge=StmtList@71:10|successor|before:AssignStmt@71:10 edge=after:AssignStmt@71:10|successor|after:StmtList@71:10 edge=after:StmtList@71:10|goto|Label@73:7 edge=before:AssignStmt@71:10|successor|IntLiteral@71:15
      end;  -- $ edge=BeginBlock@68:7|successor|HandledStmts@68:12 edge=HandledStmts@68:12|successor|StmtList@69:10
      <<Done>> X := 12;  -- $ edge=AssignStmt@73:16|successor|after:AssignStmt@73:16 edge=Identifier@73:16|successor|AssignStmt@73:16 edge=IntLiteral@73:21|successor|Identifier@73:16 edge=Label@73:7|successor|before:AssignStmt@73:16 edge=StmtList@68:7|successor|BeginBlock@68:7 edge=after:AssignStmt@73:16|successor|after:StmtList@68:7 edge=after:StmtList@68:7|successor|after:HandledStmts@67:9 edge=before:AssignStmt@73:16|successor|IntLiteral@73:21
   end Jumps;  -- $ edge=HandledStmts@67:9|successor|StmtList@68:7 edge=after:HandledStmts@67:9|successor|exitSubpBody(normal)@66:4 edge=enterSubpBody@66:4|successor|HandledStmts@67:9 edge=exitSubpBody(normal)@66:4|successor|exitSubpBody@66:4
begin
   null;  -- $ edge=NullStmt@76:4|successor|after:StmtList@76:4 edge=StmtList@76:4|successor|NullStmt@76:4 edge=after:StmtList@76:4|successor|after:HandledStmts@75:6
end Test;  -- $ edge=HandledStmts@75:6|successor|StmtList@76:4 edge=after:HandledStmts@75:6|successor|exitSubpBody(normal)@8:1 edge=enterSubpBody@8:1|successor|IntLiteral@10:19 edge=exitSubpBody(normal)@8:1|successor|exitSubpBody@8:1
