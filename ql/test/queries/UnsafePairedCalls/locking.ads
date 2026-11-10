package Locking is
   procedure Lock;
   procedure Unlock;
   type Semaphore is limited null record;
   procedure Seize (S : in out Semaphore);
   procedure Release (S : in out Semaphore);
end Locking;
