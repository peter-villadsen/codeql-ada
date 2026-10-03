with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Strings;
with Interfaces.C;

procedure Test is
   type String_Access is access String;
   type List is array (Positive range <>) of String_Access;
   type Name is new String;

   function Source (Id : Integer) return String is (Integer'Image (Id));
   procedure Sink (S : String) is null;
   procedure Sink (L : List) is null;
   procedure Sink (C : Interfaces.C.char_array) is null;

   --  Formals of Handle are sources through DataFlow.isParameterOf.
   procedure Handle (Request : String) is
   begin
      Sink (Request);  -- $ taint=param
   end Handle;

   function Ignore (S : String) return String is ("constant");
   function Sanitize (S : String) return String is (S);

   S : constant String := Source (1);
begin
   Sink ("a" & S);                                   -- $ taint=1
   Sink ("a" & "b" & S & "c");                       -- $ taint=1
   Sink (List'(1 => new String'(S)));               -- $ taint=1
   Sink (List'(1 => new String'(S)) (1).all);        -- $ taint=1
   Sink (String (Name (S)));                         -- $ taint=1
   Sink (S (S'First .. S'First + 1));                -- $ taint=1
   Sink (To_String (To_Unbounded_String (S)));       -- $ taint=1
   Sink (Ada.Strings.Fixed.Trim (S, Ada.Strings.Both));  -- $ taint=1
   Sink (Interfaces.C.To_C (S));                     -- $ taint=1
   Sink (Ignore (S));
   Sink (Sanitize (S));                              -- barrier
   Sink (Integer'Image (S'Length));
   Handle ("literal");
end Test;
