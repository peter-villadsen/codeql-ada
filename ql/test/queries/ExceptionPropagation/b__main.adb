--  Shaped like GNAT binder output: left out by the query
package body Ada_Main is
   Flag : Integer := 0;

   procedure Adainit is
   begin
      Flag := Flag / Flag;
   end Adainit;
end Ada_Main;
