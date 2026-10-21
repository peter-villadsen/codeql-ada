procedure Test is
   type Color is (Red, Green, Blue);
   S    : String (1 .. 10) := (others => ' ');
   T    : String (1 .. 10) := (others => ' ');
   C    : Color := Red;
   X    : Integer := 0;
   Flag : Boolean := False;

   procedure Set (V : out Integer) is
   begin
      V := 0;
   end Set;

   function Positive_Of (V : Integer) return Boolean is
   begin
      if V > 0 then                            --  unnecessary_if (returns)
         return True;
      else
         return False;
      end if;
   end Positive_Of;

   function Sign (V : Integer) return Integer is
   begin
      if V < 0 then                            --  nested_path: then ends with return
         return -1;
      else
         X := V;
      end if;
      if V > 0 then                            --  fine for nested_path: both return
         return 1;
      else
         return 0;
      end if;
   end Sign;
begin
   begin                                       --  block
      X := 1;
   end;
   declare
      Y : Integer := X;                        --  fine: declares something
   begin
      X := Y;
   end;
   if False then                               --  dead: static False
      X := 2;
   end if;
   if True then                                --  true_if
      X := 3;
   elsif X = 4 then                            --  dead: after a True condition
      X := 4;
   end if;
   if X = 1 then
      X := 5;
   elsif X = 1 then                            --  dead: the same condition again
      X := 6;
   end if;
   for I in 5 .. 1 loop                        --  dead: static empty range
      X := I;
   end loop;
   while False loop                            --  dead: static False
      X := 7;
   end loop;
   for I in S'Range loop                       --  for_in_for_for_of (full range)
      S (I) := 'x';                            --  also for_for_slice
   end loop;
   for I in 2 .. 5 loop                        --  for_for_slice: shifted copy; for_in (partial)
      S (I) := S (I - 1);
   end loop;
   for I in S'Range loop                       --  fine: I indexes two arrays
      S (I) := T (I);
      X := I;
   end loop;
   begin
      X := X + 1;
   exception
      when Constraint_Error =>                 --  handler: only re-raises
         raise;
   end;
   begin
      X := X + 1;
   exception
      when Constraint_Error =>                 --  fine: a non-trivial others follows
         raise;
      when others =>
         X := 0;
   end;
   if X > 0 then                               --  if: the else only holds null
      X := 1;
   else
      null;
   end if;
   if C = Red then                             --  if_for_case
      X := 1;
   elsif C = Green or C = Blue then
      X := 2;
   end if;
   if not Flag then                            --  if_not
      X := 1;
   else
      X := 2;
   end if;
   while True loop                             --  loop
      exit when X > 10;
      X := X + 1;
   end loop;
   loop                                        --  loop_for_while (and no_exit)
      exit when X > 20;
      X := X + 1;
   end loop;
   loop                                        --  loop_for_while, not no_exit
      exit when X > 30;
      X := X + 1;
      exit when X = 25;
   end loop;
   X := 1;
   null;                                       --  null: among other statements
   <<Here>> null;                              --  fine: labelled
   if X = 1 then                               --  unnecessary_if (assigns)
      Flag := True;
   else
      Flag := False;
   end if;
   while X < 100 loop                          --  while_for_for (and no_exit)
      S (1) := 'y';
      X := X + 1;
   end loop;
   while X > 0 loop                            --  fine: the step is conditional
      if Flag then
         X := X - 1;
      end if;
      Flag := not Flag;
   end loop;
   while X < 200 loop                          --  fine: X is passed to an out parameter
      Set (X);
      X := X + 1;
   end loop;
   goto Here;
   X := 0;                                     --  dead after a goto (unreachable-statement's)
end Test;
