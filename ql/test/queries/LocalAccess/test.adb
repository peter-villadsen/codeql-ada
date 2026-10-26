with Globals; use Globals;
procedure Test is
   Local_Var   : aliased Integer := 0;
   Local_Const : aliased constant Integer := 2;
   Local_Rec   : Rec;
   Local_Arr   : Arr;
   Local_Ptr   : Int_Access := Global_Var'Access;   --  fine: global
   Renamed     : Integer renames Local_Var;

   procedure Local_Proc is null;
   function Local_Func return Integer is (3);

   protected Local_PO is
      procedure Op;
      function Get return Integer;
   end Local_PO;

   protected body Local_PO is
      procedure Op is null;
      function Get return Integer is (0);
   end Local_PO;

   P  : Int_Access;
   CP : Const_Access;
   PP : Proc_Access;
   FP : Func_Access;
   type Prot_Proc is access protected procedure;
   PO_P : Prot_Proc;
begin
   P  := Local_Var'Access;                         --  BAD: variable
   P  := Local_Var'Unchecked_Access;               --  BAD: variable
   CP := Local_Const'Access;                       --  BAD: constant
   P  := Local_Rec.Field'Access;                   --  BAD: variable, through a component
   P  := Local_Arr (1)'Access;                     --  BAD: variable, through an element
   P  := Renamed'Unchecked_Access;                 --  BAD: variable, through a renaming
   P  := Local_Ptr.all'Access;                     --  fine: the designated object is not known
   PP := Local_Proc'Access;                        --  BAD: procedure
   FP := Local_Func'Access;                        --  BAD: function
   PO_P := Local_PO.Op'Access;                      --  BAD: protected procedure
   declare
      type PF is access protected function return Integer;
      X : PF := Local_PO.Get'Access;               --  BAD: protected function
   begin
      null;
   end;
   P  := Global_Var'Access;                        --  fine
   for I in 1 .. 2 loop
      declare
         Block_Var : aliased Integer := I;
      begin
         P := Block_Var'Unchecked_Access;          --  BAD: variable, in a block
      end;
   end loop;
end Test;
