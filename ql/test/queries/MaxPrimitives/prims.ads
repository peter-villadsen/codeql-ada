package Prims is
   type T is tagged null record;   --  BAD: 31 visible primitives
   procedure Op1 (X : in out T);
   procedure Op2 (X : in out T);
   procedure Op3 (X : in out T);
   procedure Op4 (X : in out T);
   procedure Op5 (X : in out T);
   procedure Op6 (X : in out T);
   procedure Op7 (X : in out T);
   procedure Op8 (X : in out T);
   procedure Op9 (X : in out T);
   procedure Op10 (X : in out T);
   procedure Op11 (X : in out T);
   procedure Op12 (X : in out T);
   procedure Op13 (X : in out T);
   procedure Op14 (X : in out T);
   procedure Op15 (X : in out T);
   procedure Op16 (X : in out T);
   procedure Op17 (X : in out T);
   procedure Op18 (X : in out T);
   procedure Op19 (X : in out T);
   procedure Op20 (X : in out T);
   procedure Op21 (X : in out T);
   procedure Op22 (X : in out T);
   procedure Op23 (X : in out T);
   procedure Op24 (X : in out T);
   procedure Op25 (X : in out T);
   procedure Op26 (X : in out T);
   procedure Op27 (X : in out T);
   procedure Op28 (X : in out T);
   procedure Op29 (X : in out T);
   procedure Op30 (X : in out T);
   procedure Op31 (X : in out T);
   type Small is null record;      --  fine: 2 primitives, 1 visible
   function Make return Small;
private
   procedure Hidden (S : Small);
end Prims;
