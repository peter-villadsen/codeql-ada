package body Types is
   procedure Use_Them (C : Color_Code; F : Flags; S : Small_Word; T : Table; E : Exp) is
      N : Count := Next + 1;
      G : Flags := F and 16#0F#;
      W : Small_Word := S * 2;
      I : Integer := T (Index'First) ** Integer (E);
      D : Derived := 0;
   begin
      if C < 3 and then G /= 0 and then W in Small_Word and then N > 0 and then D = 0 then
         null;
      end if;
   end Use_Them;
end Types;
