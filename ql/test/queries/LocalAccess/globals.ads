package Globals is
   type Int_Access is access all Integer;
   type Const_Access is access constant Integer;
   type Proc_Access is access procedure;
   type Func_Access is access function return Integer;
   type Prot_Access is access protected procedure;

   Global_Var   : aliased Integer := 0;
   Global_Const : aliased constant Integer := 1;

   type Rec is record
      Field : aliased Integer;
   end record;
   type Arr is array (1 .. 3) of aliased Integer;

   Global_Rec : Rec;
   Global_Arr : Arr;

   procedure Global_Proc;
   function Global_Func return Integer;

   protected Lib_PO is
      procedure Handler;
      function Value return Integer;
   private
      Count : aliased Integer := 0;
   end Lib_PO;

   procedure Takes_In (X : aliased Integer; P : out Int_Access);

   package Nested is
      Nested_Var : aliased Integer := 0;
   end Nested;
end Globals;
