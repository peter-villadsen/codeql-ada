package body Decls is
   Own : Integer;
   task body Worker is
      Local : Integer := 0;
   begin
      accept Start;
   end Worker;
   protected body Guard is
      entry Seize when True is
      begin
         null;
      end Seize;
      entry Release when True is
      begin
         null;
      end Release;
   end Guard;
   procedure P (X : in out Integer; Y : out Integer; Z : Integer := 0; A : access Integer) is
   begin
      P (X, Y, Z, A);                   --  BAD: self_calling_procedure
   end P;
   function F (X : Integer) return Integer is
   begin
      return F (X);                     --  BAD: self_calling_function
   end F;
   function "=" (L, R : Rec) return Boolean is
   begin
      return F (L.A) = R.A;
   end "=";
   function Relay (X : Integer) return Integer is
   begin
      return F (X);                     --  relay_function, no_spec_function
   end Relay;
   procedure Nothing is
   begin
      null;
   end Nothing;
   procedure Gen_P is
   begin
      begin
         null;
      end;
   exception
      when Constraint_Error =>
         null;
   end Gen_P;
begin
   declare
      B : Integer;
   begin
      null;
   end;
end Decls;
