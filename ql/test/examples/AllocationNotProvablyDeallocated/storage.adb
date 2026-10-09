with Ada.Unchecked_Deallocation;

procedure Storage is
   type Node;
   type Node_Access is access Node;
   type Node is record
      Value : Integer;
      Next  : Node_Access;
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Node, Node_Access);

   Shared : Node_Access;

   procedure Freed_Here is
      P : Node_Access := new Node'(1, null);       --  fine: freed below
   begin
      Free (P);
   end Freed_Here;

   procedure Release (P : in out Node_Access) is
   begin
      Free (P);
   end Release;

   procedure Freed_By_Helper is
      P : Node_Access := new Node'(2, null);       --  fine: freed in Release
   begin
      Release (P);
   end Freed_By_Helper;

   function Make return Node_Access is
   begin
      return new Node'(3, null);                   --  fine: the caller frees it
   end Make;

   procedure Freed_By_Caller is
      P : Node_Access := Make;
   begin
      Free (P);
   end Freed_By_Caller;

   procedure Never_Freed is
      P : Node_Access := new Node'(4, null);       --  BAD: never freed
   begin
      P.Value := 5;
   end Never_Freed;

   procedure Kept_In_Shared is
   begin
      Shared := new Node'(5, null);                --  reported: freed, but by another subprogram
   end Kept_In_Shared;

   procedure Linked is
      Head : Node_Access := new Node'(6, null);    --  fine: freed below
   begin
      Head.Next := new Node'(7, null);             --  reported: kept in a record component
      Free (Head.Next);
      Free (Head);
   end Linked;
begin
   Freed_Here;
   Freed_By_Helper;
   Freed_By_Caller;
   Never_Freed;
   Kept_In_Shared;
   Linked;
   Free (Shared);
end Storage;
