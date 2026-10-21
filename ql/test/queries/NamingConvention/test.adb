package body Test is
   procedure Do_It (Count : in out Integer; out_Value : out Integer) is   --  not checked again
   begin
      for i in 1 .. 3 loop                          --  BAD: i
         Count := Count + i;
      end loop;
      out_Value := Count;
   exception
      when E : others =>
         raise;
   end Do_It;
   function "+" (L, R : Shape) return Shape is (L);
   task body Worker is
   begin
      accept Start;
   end Worker;
   protected body Lock is
      procedure Seize is
      begin
         Held := True;
      end Seize;
   end Lock;
end Test;
