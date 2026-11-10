package Types is
   type Count is range 0 .. 100;          -- arithmetic: not reported
   type Color_Code is range 1 .. 5;       -- only compared: reported
   type Flags is mod 2**8;                -- only logical: reported (flags)
   type Word is mod 2**16;                -- arithmetic on a subtype: not reported
   subtype Small_Word is Word range 0 .. 255;
   type Index is range 1 .. 10;           -- only an index: reported
   type Table is array (Index) of Integer;
   type Id is private;                    -- full view without arithmetic: reported once
   type Derived is new Count;             -- a type of its own: reported
   type Exp is range 0 .. 10;             -- only an exponent: reported
   Next : Count := 0;
private
   type Id is range 0 .. 1000;
end Types;
