--  Shaped like GNAT binder output: left out by the query, whose flags are globals by design
package body Ada_Main is
   E01 : Short_Integer := 0;

   procedure Adainit is
   begin
      E01 := E01 + 1;
   end Adainit;

   procedure Adafinal is
   begin
      E01 := E01 - 1;
   end Adafinal;
end Ada_Main;
