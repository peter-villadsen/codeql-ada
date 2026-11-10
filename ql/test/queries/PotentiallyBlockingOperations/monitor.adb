with Ada.Text_IO;
with Locks;
procedure Monitor is
   task type Worker;
   task body Worker is
   begin
      null;
   end Worker;

   task Server is
      entry Start;
   end Server;

   task body Server is
   begin
      accept Start;
   end Server;

   procedure Log (S : String) is
   begin
      Ada.Text_IO.Put_Line (S);  -- reached from Shared.Set: blocking
   end Log;

   procedure Indirect is
   begin
      Log ("indirect");
   end Indirect;

   procedure Start_Server is
   begin
      Server.Start;  -- entry call: blocking
   end Start_Server;

   procedure Spawn is
      W : Worker;  -- task creation: blocking
   begin
      null;
   end Spawn;

   procedure Pause is
   begin
      delay 0.1;  -- blocking
   end Pause;

   procedure Unreached is
   begin
      Ada.Text_IO.Put_Line ("not from a protected operation");  -- not reported
      delay 0.1;
   end Unreached;

   protected Shared is
      procedure Set (V : Integer);
      function Get return Integer;
      entry Wait;
   private
      Value : Integer := 0;
      Ready : Boolean := False;
   end Shared;

   protected body Shared is
      procedure Set (V : Integer) is
      begin
         Value := V;
         Locks.Compute (Value);  -- not blocking
         Indirect;
         Locks.Wait_For_Device;  -- configured blocking subprogram
      end Set;

      function Get return Integer is
      begin
         Start_Server;
         return Value;
      end Get;

      entry Wait when Ready is
      begin
         Spawn;
         Pause;
      end Wait;
   end Shared;
begin
   Unreached;
   Shared.Set (1);
end Monitor;
