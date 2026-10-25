package body Test is

   --  Around the limit of 10.

   procedure Below_Limit (A : Boolean) is   --  9: 8 decisions
   begin
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
   end Below_Limit;

   procedure At_Limit (A : Boolean) is   --  10: 9 decisions
   begin
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
   end At_Limit;

   procedure Above_Limit (A : Boolean);   --  reported at the body, once

   procedure Above_Limit (A : Boolean) is   --  BAD: 11, 10 decisions
   begin
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
      if A then null; end if;
   end Above_Limit;

   --  A nested subprogram's decisions are its own, not the outer one's.

   procedure Outer (A : Boolean) is   --  2
      procedure Inner is   --  BAD: 11
      begin
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
         if A then null; end if;
      end Inner;
   begin
      if A then
         Inner;
      end if;
   end Outer;

   --  Each kind of decision, alone.

   procedure No_Decision is   --  1
   begin
      null;
   end No_Decision;

   procedure Kind_If (A : Boolean) is   --  2
   begin
      if A then null; end if;
   end Kind_If;

   procedure Kind_Elsif (A, B : Boolean) is   --  3: the if and the elsif
   begin
      if A then null; elsif B then null; else null; end if;
   end Kind_Elsif;

   function Kind_If_Expr (A : Boolean) return Integer is   --  2
   begin
      return (if A then 1 else 0);
   end Kind_If_Expr;

   function Kind_Elsif_Expr (A, B : Boolean) return Integer is   --  3
   begin
      return (if A then 1 elsif B then 2 else 0);
   end Kind_Elsif_Expr;

   procedure Kind_While (A : Boolean) is   --  2
   begin
      while A loop null; end loop;
   end Kind_While;

   procedure Kind_For is   --  2
   begin
      for I in 1 .. 3 loop null; end loop;
   end Kind_For;

   procedure Kind_Exit_When (A : Boolean) is   --  2: a plain loop and a plain exit are not decisions
   begin
      loop exit when A; end loop;
      loop exit; end loop;
   end Kind_Exit_When;

   function Kind_Quantified return Boolean is   --  2
   begin
      return (for all I in 1 .. 3 => I > 0);
   end Kind_Quantified;

   function Kind_And_Then (A, B : Boolean) return Boolean is   --  2
   begin
      return A and then B;
   end Kind_And_Then;

   function Kind_Or_Else (A, B : Boolean) return Boolean is   --  2
   begin
      return A or else B;
   end Kind_Or_Else;

   function Plain_And_Or (A, B, C : Boolean) return Boolean is   --  1: `and` and `or` are not
   begin
      return (A and B) or C;
   end Plain_And_Or;

   procedure Kind_Case (N : Integer) is   --  3: the alternatives after the first
   begin
      case N is
         when 1 => null;
         when 2 => null;
         when others => null;
      end case;
   end Kind_Case;

   function Kind_Case_Expr (N : Integer) return Integer is   --  3
   begin
      return (case N is when 1 => 10, when 2 => 20, when others => 0);
   end Kind_Case_Expr;

   procedure Kind_Handler is   --  3: each handler
   begin
      null;
   exception
      when Constraint_Error => null;
      when others => null;
   end Kind_Handler;

   task T is
      entry E;
   end T;

   task body T is
   begin
      accept E;
   end T;

   procedure Kind_Select is   --  2: the alternative after the first
   begin
      select
         T.E;
      or
         delay 1.0;
      end select;
   end Kind_Select;

end Test;
