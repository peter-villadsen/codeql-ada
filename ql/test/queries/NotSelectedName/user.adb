with Stacks; use Stacks;
procedure User is
   A : Object;                                --  BAD: not selected
   B : Stacks.Object;                         --  fine: selected
begin
   Push (A);
   Stacks.Push (B);
end User;

with Ada.Unchecked_Deallocation;
with Stacks;
procedure Free_User is
   type Object_Ptr is access Stacks.Object;
   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Stacks.Object, Name => Object_Ptr);   --  fine: Object names the formal
begin
   null;
end Free_User;
