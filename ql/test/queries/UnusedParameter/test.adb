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

with Missing_Pkg;  --  not available: calls into it do not resolve, nor do their arguments
procedure P6 (X : Integer) is        --  X used only in an unresolved call: fine (D-026)
begin
   Missing_Pkg.Run (X);
end P6;

procedure P7 (X : Integer with Unreferenced) is  --  marked by aspect: fine
begin
   null;
end P7;

--  Parameters that cannot be removed (v0.2.0 precision check): fine.
procedure Imposed_Profiles is
   type Visitor is access procedure (Item : Integer; Stop : in out Boolean);

   procedure Walk (Action : Visitor) is
      Stop : Boolean := False;
   begin
      Action (1, Stop);
   end Walk;

   procedure Print (Item : Integer; Stop : in out Boolean) is  --  a callback
   begin
      null;
   end Print;

   procedure Count (Unused_Item : Integer) is                   --  a junk name
   begin
      null;
   end Count;
begin
   Walk (Print'Access);
   Count (1);
end Imposed_Profiles;
