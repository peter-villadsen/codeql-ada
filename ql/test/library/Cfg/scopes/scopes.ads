package Scopes is
   function Double (X : Integer) return Integer;
   procedure With_Decl;
   task Worker;
   protected Guard is
      entry Wait;
   end Guard;
end Scopes;
