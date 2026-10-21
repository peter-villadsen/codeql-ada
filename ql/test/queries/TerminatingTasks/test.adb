with Ada.Text_IO;
procedure Test is
   Stop : Boolean := False;

   task Forever;                         --  fine: an unconditional loop, never exited
   task body Forever is
   begin
      loop
         Ada.Text_IO.Put_Line ("tick");
         delay 1.0;
      end loop;
   end Forever;

   task Once;                            --  BAD: completes
   task body Once is
   begin
      Ada.Text_IO.Put_Line ("once");
   end Once;

   task Exits;                           --  BAD: the loop is exited
   task body Exits is
   begin
      loop
         exit when Stop;
         delay 1.0;
      end loop;
   end Exits;

   task While_Loop;                      --  BAD: a while loop ends
   task body While_Loop is
   begin
      while not Stop loop
         delay 1.0;
      end loop;
   end While_Loop;

   task Server is                        --  BAD: a terminate alternative
      entry Request;
   end Server;
   task body Server is
   begin
      loop
         select
            accept Request;
         or
            terminate;
         end select;
      end loop;
   end Server;

   task Failing;                         --  BAD: raises out of the body
   task body Failing is
   begin
      loop
         if Stop then
            raise Program_Error;
         end if;
         delay 1.0;
      end loop;
   end Failing;

   task Recovering;                      --  fine: the raise is handled, the loop goes on
   task body Recovering is
   begin
      loop
         begin
            if Stop then
               raise Program_Error;
            end if;
         exception
            when others =>
               null;
         end;
         delay 1.0;
      end loop;
   end Recovering;
begin
   Stop := True;
end Test;
