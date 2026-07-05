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
end Test;
