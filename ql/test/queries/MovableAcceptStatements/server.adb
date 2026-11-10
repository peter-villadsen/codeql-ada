with Ada.Text_IO;

procedure Server is
   Count : Integer := 0;
   Total : Integer := 0;
   Log   : Integer := 0;

   task Worker is
      entry Put (V : Integer);
      entry Get (V : out Integer);
      entry Ping;
      entry Wait;
   end Worker;

   task body Worker is
      Last : Integer := 0;
   begin
      loop
         select
            accept Put (V : Integer) do
               Last := V;                        -- parameter
               Count := Count + 1;               -- movable (certain)
               Ada.Text_IO.Put_Line ("put");     -- movable (certain)
            end Put;
         or
            accept Get (V : out Integer) do
               Log := Log + 1;                   -- movable only with possible
               Total := Last;                    -- not possible: Total feeds V
               V := Total;                       -- parameter
            end Get;
         or
            accept Ping do
               null;                             -- null: not reported
            end Ping;
         or
            accept Wait do
               Count := 0;                       -- movable (certain): all of the body
               delay 0.1;                        -- synchronization
            end Wait;
         or
            terminate;
         end select;
      end loop;
   end Worker;
begin
   Worker.Put (1);
end Server;
