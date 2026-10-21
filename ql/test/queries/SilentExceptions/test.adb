with Ada.Exceptions;
with Ada.Text_IO;
procedure Test is
   Count : Integer := 0;

   procedure Log (Msg : String) renames Ada.Text_IO.Put_Line;

   procedure A is
   begin
      Count := Count + 1;
   exception
      when others =>                       --  BAD: an assignment reports nothing
         Count := 0;
   end A;

   procedure B is
   begin
      Count := Count + 1;
   exception
      when others =>                       --  BAD: the else path reports nothing
         if Count > 0 then
            raise;
         else
            Count := 0;
         end if;
   end B;

   procedure C is
   begin
      Count := Count + 1;
   exception
      when E : others =>                   --  fine: reports on every path
         if Count > 0 then
            Log (Ada.Exceptions.Exception_Message (E));
         else
            raise;
         end if;
   end C;

   procedure D is
   begin
      Count := Count + 1;
   exception
      when others =>                       --  null only: ada/exception-swallowing
         null;
   end D;

   procedure E is
   begin
      Count := Count + 1;
   exception
      when Constraint_Error =>             --  not when others: not checked by the query
         Count := 0;
      when others =>                       --  BAD: the loop may not run
         for I in 1 .. Count loop
            Log ("again");
         end loop;
   end E;
begin
   A;
   B;
   C;
   D;
   E;
end Test;
