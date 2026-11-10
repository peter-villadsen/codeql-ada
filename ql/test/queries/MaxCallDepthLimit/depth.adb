with Ada.Text_IO;

package body Depth is

   procedure Ext with Import, Convention => C, External_Name => "ext";

   procedure Leaf is
   begin
      null;
   end Leaf;

   procedure Mid is
   begin
      Leaf;                    -- depth 1
   end Mid;

   procedure Top is
   begin
      Mid;                     -- depth 2
   end Top;

   procedure Uses_Import is
   begin
      Ext;                     -- depth 1, a minimum (no body)
      Ada.Text_IO.Put_Line ("x");
   end Uses_Import;

   procedure Uses_Import_Top is
   begin
      Uses_Import;             -- depth at least 2
   end Uses_Import_Top;

   procedure Rec (N : Natural) is
   begin
      if N > 0 then
         Rec (N - 1);          -- recursive: left to ada/direct-recursion
      end if;
   end Rec;

   procedure Calls_Rec is
   begin
      Rec (3);                 -- recursive target: not reported by the query
   end Calls_Rec;

   function Sum (A, B : Integer) return Integer is
   begin
      return A + B;            -- predefined operator: depth 0
   end Sum;

begin
   Top;                        -- depth 3 > 2, at library level
   Uses_Import_Top;            -- depth at least 3 > 2
   Calls_Rec;                  -- at least 2: Rec is not analyzed
   Init := Twice (1);          -- depth 2: the expression function counts
end Depth;
