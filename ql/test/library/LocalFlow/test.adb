procedure Test (C : Boolean; N : Integer) is
   function Source return Integer is (42);
   procedure Sink (X : Integer) is null;
   function Is_Safe (X : Integer) return Boolean is (X > 0);
   A, B, D, E, F, G : Integer := 0;
begin
   A := Source;
   Sink (A);                                   --  flow: straight line

   if C then
      B := Source;
   else
      B := 1;
   end if;
   Sink (B);                                   --  flow: across a branch (phi)

   D := Source;
   for I in 1 .. N loop
      Sink (D);                                --  flow: into a loop (loop-header phi)
      E := Source;
   end loop;
   Sink (E);                                   --  flow: out of a loop (phi)

   F := Source;
   F := 1;
   Sink (F);                                   --  no flow: overwritten

   Sink ((if C then Source else 0));           --  flow: if-expression and parentheses

   G := Source;
   if Is_Safe (G) then
      Sink (G);                                --  flow, but guarded by Is_Safe
   end if;
   Sink (G);                                   --  flow, unguarded

   if C and then Is_Safe (G) then
      Sink (G);                                --  flow, guarded by a short-circuit operand
   end if;

   if not Is_Safe (G) then
      Sink (G);                                --  flow, unguarded: the check failed here
   else
      Sink (G);                                --  flow, guarded through not
   end if;

   declare
      OK : constant Boolean := Is_Safe (G);
   begin
      if OK then
         Sink (G);                             --  flow, guarded through a variable (Guards)
      end if;
   end;
end Test;
