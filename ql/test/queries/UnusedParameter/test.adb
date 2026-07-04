procedure P1 (X : Integer) is        --  spec-less, X unused: BAD
begin
   null;
end P1;

procedure P2 (X : Integer);
procedure P2 (X : Integer) is        --  spec+body, X unused: BAD
begin
   null;
end P2;

procedure P3 (X : Integer) is        --  spec-less, X used: fine
begin
   if X > 0 then
      null;
   end if;
end P3;

procedure P4 (X : Integer) is        --  spec-less, pragma Unreferenced: fine
   pragma Unreferenced (X);
begin
   null;
end P4;

procedure P5 (X : Integer);
procedure P5 (X : Integer) is        --  spec+body, X used: fine
begin
   if X > 0 then
      null;
   end if;
end P5;

package Pkg is
   type Base is tagged null record;
   procedure Foo (Self : Base; X : Integer);

   type Derived is new Base with null record;
   overriding procedure Foo (Self : Derived; X : Integer);
end Pkg;

package body Pkg is
   procedure Foo (Self : Base; X : Integer) is  --  X unused, not overriding: BAD
   begin
      null;
   end Foo;

   overriding procedure Foo (Self : Derived; X : Integer) is  --  X unused, overriding: fine
   begin
      null;
   end Foo;
end Pkg;
