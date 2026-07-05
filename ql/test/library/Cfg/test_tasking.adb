procedure Test_Tasking is

   task type Worker is
      entry Start;
      entry Stop;
      entry Redirect;
   end Worker;

   task body Worker is
   begin
      --  plain accept-do-end, outside any select
      accept Start do
         null;
      end Start;

      --  select over two accept alternatives and a delay alternative
      select
         accept Stop do
            null;
         end Stop;
      or
         accept Redirect do
            requeue Stop;
         end Redirect;
      or
         delay 1.0;
      end select;
   end Worker;

   W1, W2 : Worker;
begin
   W1.Start;
   delay 0.5;
   abort W1, W2;
end Test_Tasking;
