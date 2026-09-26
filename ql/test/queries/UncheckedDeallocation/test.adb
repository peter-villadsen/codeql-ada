with Ada.Unchecked_Deallocation;
with Unchecked_Deallocation;
with My_Generics;

procedure Test is
   type Int_Access is access Integer;

   procedure Free is new Ada.Unchecked_Deallocation   --  BAD
     (Object => Integer, Name => Int_Access);

   procedure Free_2 is new Unchecked_Deallocation     --  BAD, the Ada 83 name
     (Object => Integer, Name => Int_Access);

   generic procedure Dealloc renames Ada.Unchecked_Deallocation;

   procedure Free_3 is new Dealloc                    --  BAD, via a generic renaming
     (Object => Integer, Name => Int_Access);

   procedure Noop is new My_Generics.My_Unchecked_Deallocation (Integer);  --  fine

   P : Int_Access := new Integer'(42);
begin
   Free (P);
end Test;
