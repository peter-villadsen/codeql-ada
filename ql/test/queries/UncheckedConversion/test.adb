with Ada.Unchecked_Conversion;
with Unchecked_Conversion;
with My_Generics;

procedure Test is
   type Word is mod 2 ** 32;

   function To_Word is new Ada.Unchecked_Conversion   --  BAD
     (Source => Integer, Target => Word);

   function To_Word_2 is new Unchecked_Conversion     --  BAD, the Ada 83 name
     (Source => Integer, Target => Word);

   generic function Conv renames Ada.Unchecked_Conversion;

   function To_Word_3 is new Conv                     --  BAD, via a generic renaming
     (Source => Integer, Target => Word);

   function Same is new My_Generics.My_Unchecked_Conversion (Integer);  --  fine

   W : Word;
begin
   W := To_Word (-1);
end Test;
