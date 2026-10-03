package body Broken is
   procedure Put (Text : String; Level : Missing.Level := Missing.Info) is
   begin
      null;
   end Put;

   procedure Log (X : Missing.B) is
   begin
      null;
   end Log;

   procedure Log (X : Missing.A) is
   begin
      null;
   end Log;
end Broken;
