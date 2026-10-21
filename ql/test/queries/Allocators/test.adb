procedure Test is
   type Int_Ptr is access Integer;
   type Pos_Ptr is access Positive;
   type Str_Ptr is access String;
   type Rec is record
      X : Integer;
   end record;
   type Rec_Ptr is access Rec;
   type Shape is tagged null record;
   type Circle is new Shape with null record;
   type Shape_Ptr is access Shape'Class;
   type Color is (Red, Green);
   type Color_Ptr is access Color;
   type Small is range 1 .. 10;
   subtype Smaller is Small range 1 .. 5;
   type Small_Ptr is access Small;

   procedure Take (P : access Integer) is
   begin
      null;
   end Take;

   I : Int_Ptr := new Integer'(1);        --  fine
   P : Pos_Ptr := new Natural'(1);        --  BAD: inconsistent
   Q : Pos_Ptr := new Positive'(1);       --  fine
   S : Str_Ptr := new String'("abc");     --  fine: unconstrained array
   R : Rec_Ptr := new Rec'(X => 1);       --  fine
   C : Shape_Ptr := new Circle;           --  fine: class-wide
   K : Color_Ptr := new Color'(Red);      --  fine
   M : Small_Ptr := new Smaller'(2);      --  BAD: inconsistent
   A : access Integer := new Integer'(3); --  BAD: anonymous
begin
   Take (new Integer'(4));                --  BAD: anonymous
end Test;

package Views is
   type Node;
   type Node_Ptr is access all Node;
   type Node is record
      Next : Node_Ptr;
   end record;
   type Hidden is private;
   type Hidden_Ptr is access all Hidden;
   function Make return Hidden_Ptr;
private
   type Hidden is record
      X : Integer;
   end record;
end Views;

package body Views is
   N : Node_Ptr := new Node;              --  fine: incomplete and full view
   function Make return Hidden_Ptr is
   begin
      return new Hidden;                  --  fine: private and full view
   end Make;
end Views;
