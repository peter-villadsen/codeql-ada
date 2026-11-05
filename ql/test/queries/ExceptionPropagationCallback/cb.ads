package CB is
   type Handler is access procedure;

   procedure Register (Callback : Handler);
   procedure Log (Callback : Handler);
end CB;
