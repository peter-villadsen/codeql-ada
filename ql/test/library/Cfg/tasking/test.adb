--  CFG conformance: tasking constructs, which are deliberately opaque (D-013):
--  no inter-task edges and no rendezvous modelling.
--  See docs/cfg-design.md, "Tasking".
--
--  This family pins the fixes for two defects it surfaced: a plain
--  "accept F;" with no do block (C-3) and the abortable part of
--  "select ... then abort" (C-4). Both used to produce no CFG nodes at all,
--  so ada/unreachable-statement reported them as unreachable.
procedure Tasking is
   task T is
      entry E;
      entry F;
      entry G;
   end T;

   task body T is
   begin
      accept G do
         requeue E;  -- $ edge=RequeueStmt@19:10|successor|after:StmtList@19:10 edge=StmtList@19:10|successor|RequeueStmt@19:10 edge=after:StmtList@19:10|successor|after:HandledStmts@18:18
      end G;  -- $ edge=AcceptStmtWithStmts@18:7|successor|HandledStmts@18:18 edge=HandledStmts@18:18|successor|StmtList@19:10 edge=after:AcceptStmtWithStmts@18:7|successor|SelectStmt@22:7 edge=after:HandledStmts@18:18|successor|after:AcceptStmtWithStmts@18:7

      select
         accept E do
            null;  -- $ edge=NullStmt@24:13|successor|after:StmtList@24:13 edge=StmtList@24:13|successor|NullStmt@24:13 edge=after:StmtList@24:13|successor|after:HandledStmts@23:21
         end E;  -- $ edge=AcceptStmtWithStmts@23:10|successor|HandledStmts@23:21 edge=HandledStmts@23:21|successor|StmtList@24:13 edge=StmtList@23:10|successor|AcceptStmtWithStmts@23:10 edge=after:AcceptStmtWithStmts@23:10|successor|after:StmtList@23:10 edge=after:HandledStmts@23:21|successor|after:AcceptStmtWithStmts@23:10 edge=after:StmtList@23:10|successor|after:SelectStmt@22:7
      or
         accept F;  -- $ edge=AcceptStmt@27:10|successor|after:StmtList@27:10 edge=StmtList@27:10|successor|AcceptStmt@27:10 edge=after:StmtList@27:10|successor|after:SelectStmt@22:7
      else
         null;  -- $ edge=NullStmt@29:10|successor|after:StmtList@29:10 edge=StmtList@29:10|successor|NullStmt@29:10 edge=after:StmtList@29:10|successor|after:SelectStmt@22:7
      end select;  -- $ edge=SelectStmt@22:7|false|add.[skip1]:SelectStmt@22:7 edge=SelectStmt@22:7|true|add.[select1]:SelectStmt@22:7 edge=add.[select1]:SelectStmt@22:7|successor|StmtList@23:10 edge=add.[select2]:SelectStmt@22:7|successor|StmtList@27:10 edge=add.[skip1]:SelectStmt@22:7|false|add.[skip2]:SelectStmt@22:7 edge=add.[skip1]:SelectStmt@22:7|true|add.[select2]:SelectStmt@22:7 edge=add.[skip2]:SelectStmt@22:7|successor|StmtList@29:10 edge=after:SelectStmt@22:7|successor|SelectStmt@32:7

      select
         delay 1.0;  -- $ edge=DelayStmt@33:10|successor|after:StmtList@33:10 edge=StmtList@33:10|successor|DelayStmt@33:10 edge=after:StmtList@33:10|successor|after:SelectStmt@32:7
      then abort
         null;  -- $ edge=NullStmt@35:10|successor|after:StmtList@35:10 edge=StmtList@35:10|successor|NullStmt@35:10 edge=after:StmtList@35:10|successor|after:SelectStmt@32:7
      end select;  -- $ edge=SelectStmt@32:7|false|add.[skip1]:SelectStmt@32:7 edge=SelectStmt@32:7|true|add.[select1]:SelectStmt@32:7 edge=add.[select1]:SelectStmt@32:7|successor|StmtList@33:10 edge=add.[skip1]:SelectStmt@32:7|successor|StmtList@35:10 edge=after:SelectStmt@32:7|successor|DelayStmt@38:7

      delay 2.0;  -- $ edge=DelayStmt@38:7|successor|after:StmtList@18:7 edge=StmtList@18:7|successor|AcceptStmtWithStmts@18:7 edge=after:StmtList@18:7|successor|after:HandledStmts@17:9
   end T;  -- $ edge=HandledStmts@17:9|successor|StmtList@18:7 edge=after:HandledStmts@17:9|successor|exitTaskBody(normal)@16:4 edge=enterTaskBody@16:4|successor|HandledStmts@17:9 edge=exitTaskBody(normal)@16:4|successor|exitTaskBody@16:4
begin
   abort T;  -- $ edge=AbortStmt@41:4|successor|after:StmtList@41:4 edge=StmtList@41:4|successor|AbortStmt@41:4 edge=after:StmtList@41:4|successor|after:HandledStmts@40:6
end Tasking;  -- $ edge=HandledStmts@40:6|successor|StmtList@41:4 edge=after:HandledStmts@40:6|successor|exitSubpBody(normal)@9:1 edge=enterSubpBody@9:1|successor|HandledStmts@40:6 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
