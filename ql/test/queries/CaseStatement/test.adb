procedure Test is
   type Color is (Red, Green, Blue);
   subtype Warm is Color range Red .. Green;
   type Small is range 1 .. 10;
   type Byte is mod 2 ** 8;
   Max : constant := 5;
   C : Color := Red;
   W : Warm := Red;
   S : Small := 1;
   B : Byte := 0;
   X : Integer := 0;
   Ch : Character := 'a';
begin
   case C is                                   --  BAD: others covers nothing
      when Red => X := 1;
      when Green | Blue => X := 2;
      when others => X := 3;
   end case;
   case C is                                   --  fine: others covers Blue
      when Red | Green => X := 1;
      when others => X := 2;
   end case;
   case W is                                   --  BAD: the subtype has two values
      when Red => X := 1;
      when Green => X := 2;
      when others => null;
   end case;
   case S is                                   --  BAD: 1 .. Max and 6 .. 10 cover all
      when 1 .. Max => X := 1;
      when 6 .. 10 => X := 2;
      when others => null;
   end case;
   case S is                                   --  fine: others covers 9 and 10
      when 1 .. 8 => X := 1;
      when others => null;
   end case;
   case B is                                   --  fine: others covers 255 values
      when 0 => X := 1;
      when others => null;
   end case;
   case X is                                   --  not counted: Integer's range is not static here
      when 1 => null;
      when others => null;
   end case;
   case Ch is                                  --  fine: others covers the rest
      when 'a' .. 'z' => X := 1;
      when others => null;
   end case;
end Test;
