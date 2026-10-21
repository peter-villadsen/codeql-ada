with System.Storage_Elements;
procedure Test is
   type Small is range 1 .. 3;
   subtype Tiny is Integer range 0 .. 1;
   Reg_Addr : constant System.Address := System.Storage_Elements.To_Address (16#1000#);

   Register : Integer with Address => Reg_Addr;               --  BAD: not volatile
   Device   : Integer with Address => Reg_Addr, Volatile;     --  fine
   Status   : Integer with Atomic, Address => Reg_Addr;       --  fine: atomic is volatile
   Old      : Integer;                                        --  BAD: at clause, not volatile
   for Old'Address use Reg_Addr;
   Shared   : Integer with Volatile;                          --  volatile_no_address
   Flag     : Integer;
   pragma Volatile (Flag);                                    --  volatile_no_address
   S        : Small := 1;                                     --  span 3
   T        : Tiny := 0;                                      --  span 2
   C        : constant Integer range -5 .. 5 := 0;            --  span 11
   N        : Natural := 0;                                   --  Integer, a subtype of it
begin
   null;
end Test;
