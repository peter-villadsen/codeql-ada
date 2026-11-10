with Shared; use Shared;

procedure Workers is

   protected Guard is
      procedure Put (V : Integer);
      function Read return Integer;
      entry Wait;
   private
      Value : Integer := 0;   -- a component: always under the lock
   end Guard;

   protected body Guard is
      procedure Put (V : Integer) is
      begin
         Value := V;
      end Put;

      function Read return Integer is
      begin
         return Get_Total + Value;  -- reads Total through a call
      end Read;

      entry Wait when Value > 0 is
      begin
         Flag2 := True;             -- written through an entry call
      end Wait;
   end Guard;

   task A;
   task B;

   task type Worker;

   task body A is
      Local : Integer := 0;         -- local to the task: never global
   begin
      Bump;                         -- writes Counter through a call
      Local := Local + Limit;
      Flag := True;
      Total := Local;
      Guard.Put (Local);
   end A;

   task body B is
   begin
      Counter := Counter - 1;
      if Flag and then Limit > Max then
         Flag2 := False;
      end if;
      Guard.Wait;
   end B;

   task body Worker is
   begin
      Per_Type := Per_Type + 1;
   end Worker;

   W1, W2 : Worker;

   procedure Main_Only is
      Nested_Global : Integer := 0;

      procedure Inner is
      begin
         Nested_Global := 1;        -- global to Inner, local to Main_Only
      end Inner;
   begin
      Inner;
      Set_Only;
   end Main_Only;

begin
   Main_Only;
end Workers;
