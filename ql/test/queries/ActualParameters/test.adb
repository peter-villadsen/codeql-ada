with Ada.Unchecked_Conversion;

procedure Test is
   type Word is mod 2 ** 32;

   function To_Word is new Ada.Unchecked_Conversion (Integer, Word);

   procedure Put (Item : Integer; Width : Natural := 0; Base : Positive := 10) is
   begin
      null;
   end Put;

   procedure Store (W : Word) is
   begin
      null;
   end Store;

   generic
      Size : Positive := 8;
      Fill : Character := ' ';
   package Buffers is
      Data : String (1 .. Size) := (others => Fill);
   end Buffers;

   package B1 is new Buffers;                     --  default_used: Size, Fill
   package B2 is new Buffers (16);                --  default_positional: Size
   package B3 is new Buffers (Size => 16);        --  fine: named
   package B4 is new Buffers (16, Fill => '*');   --  default_positional: Size

   I : Integer := 5;
begin
   Put (1);                         --  fine: Item has no default
   Put (1, 5);                      --  default_positional: Width
   Put (1, Width => 5);             --  fine
   Put (1, 5, 16);                  --  default_positional: Width, Base
   Put (Item => 1, Base => 2);      --  fine
   Store (To_Word (I));             --  BAD: unchecked conversion as the actual
   Store (Word'(To_Word (I)));      --  BAD: qualified, still the conversion
   Store (To_Word (I) + 1);         --  fine: part of a larger expression
   Store (Word (I));                --  fine: an ordinary conversion
end Test;
