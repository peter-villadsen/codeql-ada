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
         requeue E;  -- $ edge=RequeueStmt@19:10|successor|AcceptStmt@27:10 edge=RequeueStmt@19:10|successor|AcceptStmtWithStmts@23:10 edge=RequeueStmt@19:10|successor|NullStmt@29:10
      end G;  -- $ edge=AcceptStmtWithStmts@18:7|successor|RequeueStmt@19:10

      select
         accept E do
            null;  -- $ edge=NullStmt@24:13|successor|SelectStmt@22:7
         end E;  -- $ edge=AcceptStmtWithStmts@23:10|successor|NullStmt@24:13
      or
         accept F;  -- $ edge=AcceptStmt@27:10|successor|SelectStmt@22:7
      else
         null;  -- $ edge=NullStmt@29:10|successor|SelectStmt@22:7
      end select;  -- $ edge=SelectStmt@22:7|successor|DelayStmt@33:10 edge=SelectStmt@22:7|successor|NullStmt@35:10

      select
         delay 1.0;  -- $ edge=DelayStmt@33:10|successor|SelectStmt@32:7
      then abort
         null;  -- $ edge=NullStmt@35:10|successor|SelectStmt@32:7
      end select;  -- $ edge=SelectStmt@32:7|successor|DelayStmt@38:7

      delay 2.0;  -- $ edge=DelayStmt@38:7|successor|exitTaskBody(normal)@16:4
   end T;  -- $ edge=enterTaskBody@16:4|successor|AcceptStmtWithStmts@18:7 edge=exitTaskBody(normal)@16:4|successor|exitTaskBody@16:4
begin
   abort T;  -- $ edge=AbortStmt@41:4|successor|exitSubpBody(normal)@9:1
end Tasking;  -- $ edge=enterSubpBody@9:1|successor|AbortStmt@41:4 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
