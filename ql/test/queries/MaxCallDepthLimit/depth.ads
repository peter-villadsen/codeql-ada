package Depth is
   procedure Leaf;
   procedure Mid;
   procedure Top;
   procedure Uses_Import;
   procedure Uses_Import_Top;
   procedure Rec (N : Natural);
   procedure Calls_Rec;
   function Sum (A, B : Integer) return Integer;
   function Twice (A : Integer) return Integer is (Sum (A, A));
   Init : Integer;
end Depth;
