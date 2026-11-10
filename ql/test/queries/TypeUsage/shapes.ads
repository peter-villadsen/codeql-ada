package Shapes is
   type Color is (Red, Green, Blue);
   type Code is (Low, High);
   for Code use (Low => 1, High => 4);
   type Light is new Color;
   subtype Warm is Color range Red .. Green;
   type Byte is mod 256;
   type Small is range 1 .. 10;
   type Point is record
      X, Y : Integer;
   end record;
   type Sized is record
      Z : Integer;
   end record;
   for Sized'Size use 32;
   type Table is array (Byte) of Integer;      -- reported: mod index
   type Grid is array (Small range <>, Byte range <>) of Integer;  -- reported once: mod index
   type List is array (Small) of Integer;     -- not reported
   function Show (C : Light) return String is (Light'Image (C));  -- reported: derived from Color
   function Show_Warm (C : Warm) return String is (Warm'Image (C));  -- reported: subtype
   function Pos (C : Code) return Integer is (Code'Pos (C));  -- reported: representation
   function Pos2 (C : Color) return Integer is (Color'Pos (C));  -- not reported: no clause
   P_Size : constant Integer := Point'Size;  -- reported: no size clause
   S_Size : constant Integer := Sized'Size;  -- not reported: size clause
end Shapes;
