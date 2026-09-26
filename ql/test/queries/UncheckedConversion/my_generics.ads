package My_Generics is
   --  A user generic whose name merely ends like the runtime one.
   generic
      type T is private;
   function My_Unchecked_Conversion (X : T) return T;
end My_Generics;
