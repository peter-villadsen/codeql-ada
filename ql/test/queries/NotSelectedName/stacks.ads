package Stacks is
   type Object is tagged null record;
   procedure Push (S : in out Object);        --  fine: in the declaring unit
   Empty : constant Object := (null record);
end Stacks;
