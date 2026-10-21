with Ada.Text_IO;
procedure Test is
   task Logger is
      entry Log (Msg : String);
   end Logger;
   task body Logger is
   begin
      accept Log (Msg : String) do
         Ada.Text_IO.Put_Line (Msg);
      end Log;
   end Logger;

   protected Lock is
      entry Seize;
      procedure Release;
   private
      Held : Boolean := False;
   end Lock;
   protected body Lock is
      entry Seize when not Held is
      begin
         Held := True;
      end Seize;
      procedure Release is
      begin
         Held := False;
      end Release;
   end Lock;

   procedure Report (Msg : String) renames Ada.Text_IO.Put_Line;
begin
   Logger.Log ("start");                  --  fine: not in a handler
exception
   when Constraint_Error =>
      Logger.Log ("failed");              --  BAD: entry call
      Lock.Seize;                         --  BAD: entry call
      Lock.Release;                       --  calls, not an entry call
      Report ("failed");                  --  a call; references Put_Line, renamed
   when others =>
      Ada.Text_IO.Put_Line ("others");    --  a call; references Put_Line
end Test;
