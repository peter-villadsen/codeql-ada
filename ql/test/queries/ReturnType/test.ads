package Test is
   type Shape is tagged null record;
   type Lim is limited interface;
   type Vec is array (Positive range <>) of Integer;
   type Fixed is array (1 .. 3) of Integer;
   type Rec (N : Natural) is record
      Data : Vec (1 .. N);
   end record;
   subtype Rec3 is Rec (3);
   task type Worker;
   type Pool is record
      W : Worker;
   end record;
   protected type Lock is
      procedure Seize;
   end Lock;

   function Ptr return access Integer;                --  BAD: anonymous_access
   function Any_Shape return Shape'Class;             --  class_wide
   function Any_Lim return Lim'Class;                 --  class_wide, limited_class_wide
   function Values return Vec;                        --  unconstrained_array
   function Triple return Fixed;                      --  constrained_array
   function Make return Rec;                          --  unconstrained_discriminated
   function Make3 return Rec3;                        --  fine: constrained subtype
   function New_Pool return Pool;                     --  task
   function Count return Natural;                     --  type Integer (a subtype)
end Test;
