package body Globals is
   Body_Var : aliased Integer := 0;

   procedure Global_Proc is null;
   function Global_Func return Integer is (1);

   protected body Lib_PO is
      procedure Handler is
         P : Int_Access;
      begin
         P := Count'Unchecked_Access;              --  fine: a component of a library-level protected object
         Count := Count + 1;
      end Handler;
      function Value return Integer is (Count);
   end Lib_PO;

   procedure Takes_In (X : aliased Integer; P : out Int_Access) is
   begin
      P := X'Unrestricted_Access;                  --  BAD: constant, a parameter
   end Takes_In;

   A : Int_Access := Body_Var'Access;              --  fine: global, in a package body
   B : Int_Access := Nested.Nested_Var'Access;     --  fine: global, in a nested package
   C : Const_Access := Global_Const'Access;        --  fine
   D : Int_Access := Global_Rec.Field'Access;      --  fine: a component of a global
   E : Int_Access := Global_Arr (2)'Access;        --  fine: an element of a global
   F : Proc_Access := Global_Proc'Access;          --  fine
   G : Prot_Access := Lib_PO.Handler'Access;       --  fine
end Globals;
