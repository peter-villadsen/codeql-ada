procedure Test (A : Boolean) is
begin
   if A then
      if A then
         if A then
            if A then
               if A then
                  if A then   --  BAD: the outermost too deep (6)
                     if A then
                        null;
                     end if;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end if;
   for I in 1 .. 2 loop
      for J in 1 .. 2 loop
         declare
         begin
            null;
         end;
      end loop;
   end loop;
end Test;
