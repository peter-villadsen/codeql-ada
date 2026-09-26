package My_Generics is
   --  A user generic whose name merely ends like the runtime one.
   generic
      type T is private;
   procedure My_Unchecked_Deallocation (X : T);
end My_Generics;
