package Pkg is
   procedure Run;
   Internal_Limit : constant Integer := 3;  -- reported: to body
   type Shape is tagged null record;
   procedure Draw (S : Shape) is null;      -- not reported: primitive
   type Shared_Count is range 0 .. 10;      -- not reported: used in the spec
   procedure Count (C : Shared_Count) is null;
end Pkg;
