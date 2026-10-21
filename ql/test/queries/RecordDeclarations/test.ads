package Test is
   type Color is (Red, Green);
   type Bits is array (1 .. 8) of Boolean;
   pragma Pack (Bits);
   type Rec (D : Boolean) is record
      C1 : Color;                            --  BAD: enumeration, no default
      C2 : Color := Red;                     --  fine
      N  : Integer;
      B  : Bits;                             --  packed
      case D is
         when True =>
            V : Color;                       --  BAD; in_variant
         when False =>
            null;
      end case;
   end record;
   for Rec use record
      D  at 0 range 0 .. 0;
      C1 at 0 range 1 .. 7;                  --  sized, not aligned
      N  at 4 range 0 .. 31;                 --  sized, aligned
   end record;
end Test;
