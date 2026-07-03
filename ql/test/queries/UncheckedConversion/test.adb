with Ada.Unchecked_Conversion;

procedure Test is
   type Word is mod 2 ** 32;

   function To_Word is new Ada.Unchecked_Conversion   --  BAD
     (Source => Integer, Target => Word);

   W : Word;
begin
   W := To_Word (-1);
end Test;
