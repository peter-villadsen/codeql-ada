package Test is
   function Get (X : Integer) return Integer;
   function Get (X : Float) return Float;
   pragma Inline (Get);                      --  BAD: multiple (two Get)
   function Single (X : Integer) return Integer;
   pragma Inline (Single);                   --  fine: one entity
   pragma Assert (Single (1) > 0);           --  not multiple: an evaluated condition
   pragma Unreferenced (Single);             --  nonstandard (GNAT)
   pragma Pure_Funktion (Single);            --  nonstandard (unrecognized: a typo)
   pragma Preelaborate;                      --  standard
end Test;
