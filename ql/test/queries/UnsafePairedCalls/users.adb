with Locking; use Locking;
procedure Users is
   A, B : Semaphore;
   Done : Boolean := False;

   procedure Work is null;

   procedure Safe is
   begin
      Lock;
      Work;
      Unlock;
   exception
      when others =>
         Unlock;
         raise;
   end Safe;

   procedure Safe_Return is
   begin
      Lock;
      if Done then
         Unlock;
         return;
      end if;
      Work;
      Unlock;
      return;
   exception
      when Constraint_Error =>
         Unlock;
      when others =>
         Unlock;
         raise;
   end Safe_Return;

   procedure Not_First is
   begin
      Work;
      Lock;      -- reported: not first
      Unlock;    -- reported: no opening for it
   end Not_First;

   procedure No_Handler is
   begin
      Lock;      -- reported: no others handler
      Work;
      Unlock;
   end No_Handler;

   procedure Leaky_Return is
   begin
      Lock;      -- reported: return without closing
      if Done then
         return;
      end if;
      Unlock;
   exception
      when others =>
         Unlock;
         raise;
   end Leaky_Return;

   procedure Bad_Handler is
   begin
      Lock;      -- reported: a handler does not close
      Work;
      Unlock;
   exception
      when Constraint_Error =>
         null;
      when others =>
         Unlock;
         raise;
   end Bad_Handler;

   procedure Wrong_Lock is
   begin
      Seize (A);   -- reported: closed with another lock
      Work;
      Release (B); -- reported: does not close
   exception
      when others =>
         Release (A);
         raise;
   end Wrong_Lock;

   procedure Right_Lock is
   begin
      Seize (A);
      Work;
      Release (A);
   exception
      when others =>
         Release (A);
         raise;
   end Right_Lock;
begin
   Safe;
end Users;
