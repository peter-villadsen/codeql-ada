procedure Test is
   function Many (X : Integer) return Integer is   --  BAD: 6 regular returns
   begin
      if X = 1 then
         return 1;
      elsif X = 2 then
         return 2;
      elsif X = 3 then
         return 3;
      elsif X = 4 then
         for I in 1 .. X loop
            if I = 2 then
               return 4;                            --  depth 3
            end if;
         end loop;
      end if;
      declare
      begin
         return 5;                                  --  depth 1, in a block
      exception
         when others =>
            return 0;                               --  a handler of the block
      end;
      return 6;
   exception
      when Constraint_Error =>
         return -1;
      when others =>
         return -2;
   end Many;

   procedure Proc (X : Integer) is                 --  fine: 1 return
   begin
      if X > 0 then
         return;
      end if;
   end Proc;

   task T is
      entry E (X : Integer);
   end T;
   task body T is
   begin
      accept E (X : Integer) do
         if X > 0 then
            return;                                 --  an entry (accept) return
         end if;
      end E;
   end T;
begin
   Proc (Many (1));
end Test;
