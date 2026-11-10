package Shared is
   Counter   : Integer := 0;       -- written by two tasks
   Limit     : Integer := 10;      -- only read by tasks
   Flag      : Boolean := False with Atomic;  -- atomic, written by one task
   Flag2     : Boolean := False with Atomic;  -- atomic, written by two tasks
   Total     : Integer := 0;       -- written by one task, read by a protected object
   Per_Type  : Integer := 0;       -- written by a task type
   Only_Proc : Integer := 0;       -- written by subprograms only
   Max       : constant Integer := 100;

   procedure Bump;
   function Get_Total return Integer;
   procedure Set_Only;
end Shared;
