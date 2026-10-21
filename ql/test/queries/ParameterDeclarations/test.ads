package Test is
   type Shape is tagged null record;
   procedure Many (A, B, C, D, E, F, G, H, I, J, K : Integer);   --  BAD: 11 parameters
   procedure Ten (A, B, C, D, E, F, G, H, I, J : Integer);       --  fine: 10
   procedure Get (X : out Integer);                              --  single_out_parameter
   procedure Get2 (X : out Integer; Y : in out Integer);         --  single, but an in out too
   function F (S : Shape; P : access Integer; Q : Integer := 0) return Integer;
   procedure Draw (S : Shape'Class);
   task type Worker is
      entry Start (N : Integer);
   end Worker;
   protected Lock is
      procedure Seize (Who : Integer);
   end Lock;
end Test;
