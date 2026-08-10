--  CFG conformance: tasking constructs, which are deliberately opaque (D-013):
--  no inter-task edges and no rendezvous modelling.
--  See docs/cfg-design.md, "Tasking".
--
--  This family pins the fixes for two defects it surfaced: a plain
--  "accept F;" with no do block (C-3) and the abortable part of
--  "select ... then abort" (C-4). Both used to produce no CFG nodes at all,
--  so ada/unreachable-statement reported both as unreachable.
procedure Tasking is
   task T is
      entry E;
      entry F;
   end T;

   task body T is
   begin
      select
         accept E do
            null;  -- $ edge=NullStmt@19:13|successor|SelectStmt@17:7
         end E;
      or
         accept F;  -- $ edge=AcceptStmt@22:10|successor|SelectStmt@17:7
      else
         null;  -- $ edge=NullStmt@24:10|successor|SelectStmt@17:7
      end select;  -- $ edge=SelectStmt@17:7|successor|DelayStmt@28:10 edge=SelectStmt@17:7|successor|NullStmt@30:10

      select
         delay 1.0;  -- $ edge=DelayStmt@28:10|successor|SelectStmt@27:7
      then abort
         null;  -- $ edge=NullStmt@30:10|successor|SelectStmt@27:7
      end select;  -- $ edge=SelectStmt@27:7|successor|DelayStmt@33:7

      delay 2.0;  -- $ edge=DelayStmt@33:7|successor|exitTaskBody(normal)@15:4
   end T;  -- $ edge=enterTaskBody@15:4|successor|AcceptStmt@22:10 edge=enterTaskBody@15:4|successor|NullStmt@19:13 edge=enterTaskBody@15:4|successor|NullStmt@24:10 edge=exitTaskBody(normal)@15:4|successor|exitTaskBody@15:4
begin
   null;  -- $ edge=NullStmt@36:4|successor|exitSubpBody(normal)@9:1
end Tasking;  -- $ edge=enterSubpBody@9:1|successor|NullStmt@36:4 edge=exitSubpBody(normal)@9:1|successor|exitSubpBody@9:1
