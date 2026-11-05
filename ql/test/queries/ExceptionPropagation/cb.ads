package CB is
   type Handler is access procedure;

   procedure Register (Callback : Handler);

   procedure Exported_Pragma (X : Integer);
   pragma Export (C, Exported_Pragma, "exported_pragma");

   procedure Exported_Aspect (X : Integer)
     with Export, Convention => C, External_Name => "exported_aspect";

   procedure Exported_Safe (X : Integer);
   pragma Export (C, Exported_Safe, "exported_safe");

   procedure Exported_Null;
   pragma Export (C, Exported_Null, "exported_null");

   procedure Not_Exported (X : Integer);
end CB;
