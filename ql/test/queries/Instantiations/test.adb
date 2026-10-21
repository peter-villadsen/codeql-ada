with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
procedure Test is
   type Word is mod 2 ** 32;
   subtype Small is Integer range 0 .. 10;
   type Int_Ptr is access Integer;

   function To_Word is new Ada.Unchecked_Conversion (Integer, Word);
   function To_Word_2 is new Ada.Unchecked_Conversion          --  BAD: same actuals
     (Source => Integer, Target => Word);
   function To_Int is new Ada.Unchecked_Conversion (Word, Integer);   --  fine
   function Small_To_Word is new Ada.Unchecked_Conversion (Small, Word);
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Ptr);
   procedure Free_Again is new Ada.Unchecked_Deallocation (Integer, Int_Ptr);   --  BAD

   generic
      type T is private;
   package Holder is
      V : T;
   end Holder;
   package H1 is new Holder (Integer);
begin
   declare
      package H2 is new Holder (Word);
   begin
      null;
   end;
end Test;
