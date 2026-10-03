package body Pkg is
   procedure Foo (X : Integer) is
   begin
      null;
   end Foo;

   procedure Foo (X : Float) is
   begin
      null;
   end Foo;

   function Square (X : Integer) return Integer is (X * X);

   procedure Stub_Only is separate;  --  no separate declaration: the stub pairs with the subunit

   procedure Outer is
      procedure Inner;

      procedure Inner is
      begin
         null;
      end Inner;
   begin
      Inner;
   end Outer;
end Pkg;
