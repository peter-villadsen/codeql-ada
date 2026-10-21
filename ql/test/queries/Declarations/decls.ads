with Ada.Finalization;
package Decls is
   type Int is range 1 .. 10;
   type Word is mod 2 ** 16;
   type Real is digits 6;
   type Fix is delta 0.01 range 0.0 .. 1.0;
   type Dec is delta 0.01 digits 5;
   type Color is (Red, Green, 'x');
   subtype Small is Int range 1 .. 5;
   type Arr is array (1 .. 3) of Integer;
   type Open_Arr is array (Positive range <>) of aliased Integer;
   type Int_Ptr is access all Integer;
   type Const_Ptr is access constant Integer;
   type Proc_Ptr is access procedure;
   type Arr_Ptr is access Open_Arr;
   type Rec is record
      A, B : Integer;
      C    : Integer := 0;
      P    : access Integer;
   end record;
   type Empty is null record;
   type Tag is tagged null record;
   type Abs_Tag is abstract tagged null record;
   type Child is new Tag with null record;
   type Child2 is new Tag with record
      X : Integer;
   end record;
   type Derived is new Int;
   type Iface is interface;
   type Disc (N : Natural := 0) is record
      case N is
         when 0 => null;
         when others => V : Integer;
      end case;
   end record;
   type Priv is private;
   type Lim is limited private;
   type Tag_Priv is tagged private;
   type Priv_Ext is new Tag with private;
   type Inc;
   type Inc_Ptr is access Inc;
   type Inc is null record;
   task type Worker is
      entry Start;
   end Worker;
   protected type Guard is
      entry Seize;
      entry Release;
   end Guard;
   Max : constant := 10;
   Deferred : constant Integer;
   Oops : exception;
   V1, V2 : Integer;
   V3 : aliased Integer := 1;
   V4 : array (1 .. 2) of Integer;
   C1 : constant Integer := 1;
   procedure P (X : in out Integer; Y : out Integer; Z : Integer := 0; A : access Integer);
   function F (X : Integer) return Integer;
   function "=" (L, R : Rec) return Boolean;
   procedure Abs_P (X : Abs_Tag) is abstract;
   procedure N is null;
   function E (X : Integer) return Integer is (X + 1);
   generic
      Size : Positive := 8;
      with procedure Act is null;
      with function Cmp (L, R : Integer) return Boolean is <>;
   package Gen is
   end Gen;
   generic
   procedure Gen_P;
   package Inst is new Gen;
private
   type Priv is new Integer;
   type Lim is limited null record;
   type Tag_Priv is tagged null record;
   type Priv_Ext is new Tag with null record;
   Deferred : constant Integer := 1;
end Decls;
