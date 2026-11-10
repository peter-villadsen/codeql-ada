package Registry is
   type Int_Ptr is access Integer;
   procedure Register (Name : String);
   procedure Setup;
   procedure Late;
   procedure Never_Called;
   Default : Int_Ptr := new Integer'(0);      -- elaboration: allowed
end Registry;
