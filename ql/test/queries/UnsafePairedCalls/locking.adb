package body Locking is
   procedure Lock is null;
   procedure Unlock is null;
   procedure Seize (S : in out Semaphore) is null;
   procedure Release (S : in out Semaphore) is null;
end Locking;
