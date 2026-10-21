--  Header comment: not terminating.
package body Test is   --  terminating
   type Short is record
      X : Integer;
   end record;

   type Long is record
      A : Integer;
      B : Integer;
      C : Integer;
      D : Integer;
      E : Integer;
      F : Integer;
      G : Integer;
      H : Integer;
   end record;                      --  BAD: more than 10 lines, unnamed

   type Named is record
      A : Integer;
      B : Integer;
      C : Integer;
      D : Integer;
      E : Integer;
      F : Integer;
      G : Integer;
      H : Integer;
   end record;  -- Named, the record
   type Wrong is record
      A : Integer;
   end record;  -- Old_Name           BAD: names something else

   procedure P is
   begin  --  P
      null;
   end P;

   procedure Q is
      X : Integer := 0;   --  TBSL: a better initial value
   begin
      --  position 7
--  position 1
      X := X + 1;
   end Q;

   function F return Integer is
      procedure Inner is null;
   begin --  wrong
      return 1;
   end F;
begin
   null;
end Test;
