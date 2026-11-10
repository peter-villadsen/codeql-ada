package body Pkg is
   Counter : Integer;                       -- not reported: would lose its value between calls

   procedure Helper is null;                -- reported: only Run calls it

   type Local_Kind is (A, B);               -- reported: only used in Run

   Total : Integer;                         -- reported: only in the block

   Never_Used : Integer;                    -- reported: not used
   Marked : Integer with Unreferenced;      -- not reported: unused on purpose
   procedure Callback with Export, Convention => C, External_Name => "cb";  -- not reported: exported
   procedure Callback is null;
   function Next return Integer is (1);
   Kept : constant Integer := Next;         -- not reported: initialized by a call

   Aliased_Var : aliased Integer;           -- not reported: 'Access taken
   type Int_Ptr is access all Integer;
   P : Int_Ptr := Aliased_Var'Access;

   procedure Run is
      K : Local_Kind := A;
      Loop_Var : Integer;                   -- not reported: would move into a loop
   begin
      Helper;
      Counter := Counter + Internal_Limit;
      for I in 1 .. 3 loop
         declare
            Tmp : Integer := I;
         begin
            Loop_Var := Tmp;
         end;
      end loop;
      if K = B then
         Counter := 0;
      end if;
   end Run;
begin
   declare
      X : Integer := 0;
   begin
      Total := X;
      X := Total;
   end;
   P.all := 1;
end Pkg;
