package Debug is
   procedure Trace (Msg : String);
   generic
      type T is private;
   procedure Dump (X : T);
end Debug;
