with System;
package Test is
   type Color is (Red, Green, Blue);
   for Color use (1, 2, 4);                       --  enumeration
   for Color'Size use 3;                          --  'size, fractional_size

   type Header is record
      Kind  : Integer;
      Len   : Integer;
      Flags : Integer;
   end record;
   for Header use record                          --  BAD: incomplete (Flags); layout
      Kind at 0 range 0 .. 31;
      Len  at 4 range 0 .. 31;
   end record;
   for Header'Size use 96;                        --  non_power2_size

   type Full is record
      A : Integer;
   end record;
   for Full'Bit_Order use System.Low_Order_First;
   for Full use record                            --  fine: complete, with a bit order
      A at 0 range 0 .. 31;
   end record;

   Base  : Integer;
   Alias : Integer;
   for Alias'Address use Base'Address;            --  overlay, 'address, object
end Test;
