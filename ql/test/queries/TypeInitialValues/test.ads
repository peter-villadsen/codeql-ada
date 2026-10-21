package Test is
   type Point is record                     --  fine: Origin
      X, Y : Integer;
   end record;
   Origin : constant Point := (0, 0);

   type Item is record                      --  BAD: no constant
      N : Integer;
   end record;

   type Handle is private;                  --  fine: Null_Handle (deferred)
   Null_Handle : constant Handle;

   type Count is range 0 .. 10;             --  no constant (not a record: not in the query)
   C_Init_Count : constant Count := 0;      --  an initial value matching "^C_Init_"
private
   type Handle is record
      Id : Integer;
   end record;
   Null_Handle : constant Handle := (Id => 0);
end Test;
