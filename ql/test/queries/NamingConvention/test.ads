package Test is
   type Color is (Red, green);                      --  BAD: green
   type Int_Ptr is access Integer;
   type Shape is tagged null record;
   type Shape_Ptr is access Shape'Class;
   subtype Small is Integer range 1 .. 10;
   Max_Count : constant := 10;
   Ratio     : constant := 0.5;
   my_Var    : Integer := 0;                        --  BAD
   GPR2_Path : Integer := 0;                        --  fine: an acronym
   Bad_name  : Boolean := False;                    --  BAD
   Failure   : exception;
   procedure Do_It (Count : in out Integer; out_Value : out Integer);   --  BAD: out_Value
   function "+" (L, R : Shape) return Shape;        --  not checked: an operator
   generic
      type Element is private;
   package Holder is
   end Holder;
   package Int_Holder is new Holder (Integer);
   task type Worker is
      entry Start;
   end Worker;
   protected Lock is
      procedure Seize;
   private
      Held : Boolean := False;
   end Lock;
end Test;

package Test.Child_unit is                         --  BAD: unit
end Test.Child_unit;
