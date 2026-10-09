with Ada.Text_IO;

procedure Test is
   procedure P1 is
   begin
      return;
      Ada.Text_IO.Put_Line ("unreachable after return");
   end P1;

   procedure P2 is
   begin
      raise Program_Error;
      Ada.Text_IO.Put_Line ("unreachable after raise");
   end P2;

   procedure P3 is
   begin
      Ada.Text_IO.Put_Line ("reachable");
      return;
   end P3;

   procedure Stop with No_Return;
   procedure Stop is
   begin
      raise Program_Error;
   end Stop;

   procedure P5 (N : Integer; X : in out Integer) is
   begin
      X := 1;
      pragma Assert (X = 1);                     --  fine: a pragma is a step
      for I in Natural range 0 .. N loop        --  fine: reachable loop over a subtype
         X := I;
      end loop;
      X := 0;                                    --  fine: reachable after both
      Stop;
      Ada.Text_IO.Put_Line ("unreachable after a No_Return call");
   end P5;

   procedure P4 (C : Boolean) is
   begin
      if C then
         return;
      else
         return;
      end if;
      Ada.Text_IO.Put_Line ("unreachable after if/else that both return");
   end P4;
begin
   P1;
   P2;
   P3;
   P4 (True);
   declare
      V : Integer := 0;
   begin
      P5 (1, V);
   end;
end Test;

--  Not statements that run (v0.2.0 precision check): fine.
procedure Not_Run (X : Integer) is
begin
   if X < 0 then
      pragma Annotate (Xcov, Exempt_On, "defensive code");
      raise Program_Error;
      pragma Annotate (Xcov, Exempt_Off);
   end if;
end Not_Run;
