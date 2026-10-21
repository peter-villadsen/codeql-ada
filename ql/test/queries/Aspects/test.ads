package Test is
   procedure P with Inline;                            --  BAD: implicit True
   procedure Q with Inline => True;                    --  fine
   procedure R (X : Integer)
     with Pre => X > 0, Post => True, No_Return;       --  BAD: No_Return
   type T is tagged null record;
   procedure S (X : T) with Pre'Class => True;         --  fine
   V : Integer with Volatile, Atomic => False;         --  BAD: Volatile
end Test;
