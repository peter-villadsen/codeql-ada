with Ada.Unchecked_Deallocation;

procedure Test is
   type Int_Access is access Integer;

   procedure Free is new Ada.Unchecked_Deallocation   --  BAD
     (Object => Integer, Name => Int_Access);

   P : Int_Access := new Integer'(42);
begin
   Free (P);
end Test;
