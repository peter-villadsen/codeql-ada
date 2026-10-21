procedure Test is
   type Color is (Red, Green, Blue);
   C : Color := Red;
   X : Integer := 0;
   Arr : array (1 .. 3) of Integer := (others => 0);

   function F (Y : Integer) return Integer is
   begin
      if Y > 0 then
         return 1;
      end if;
      return 0;                                 --  function_return (2)
   end F;
begin
   case C is
      when Red => X := 1;
      when others => null;                      --  BAD: case_others_null
   end case;
   <<Again>>
   X := X + 1;
   if X < 10 then
      goto Again;                               --  BAD: backward_goto
   end if;
   Outer : loop
      for I in 1 .. 3 loop                      --  untyped_for_in
         exit Outer when I = X;                 --  exit_outer_loop, named_exit
      end loop;
      exit;                                     --  unconditional_exit
   end loop Outer;
   for E of Arr loop                            --  for_of_loop, untyped_for_of
      null;                                     --  null_loop_body
   end loop;
   while X > 0 loop
      X := X - 1;
      exit when X = 5;
      exit when X = 3;                          --  multiple_exits
   end loop;
   for I in 1 .. 3 loop
      if I = 2 then
         goto Continue;                         --  goto, a continue
      end if;
      X := X + I;
      <<Continue>> null;
   end loop;
   begin
      X := F (X);
   exception
      when others =>
         raise Constraint_Error;                --  raise_standard
   end;
   declare
      Y : Integer := X;
   begin
      X := Y;
   end;
   delay 0.1;
end Test;
