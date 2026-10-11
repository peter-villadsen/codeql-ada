with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Strings;
with Interfaces.C;
with Ada.Directories;

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

   --  A string built element by element keeps the taint of its elements.
   function Copy_Elements (S : String) return String is
      R : String (1 .. S'Length);
   begin
      for I in S'Range loop
         R (I - S'First + 1) := S (I);
      end loop;
      return R;
   end Copy_Elements;

   function Copy_Of (S : String) return String is
      R    : String (1 .. S'Length) := (others => ' ');
      Last : Natural := 0;
   begin
      for C of S loop
         Last := Last + 1;
         R (Last) := C;
      end loop;
      return R;
   end Copy_Of;

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
   Sink (Integer'Image (Integer'Value (S)));          -- $ taint=1
   Sink (Character'Val (Character'Pos (S (S'First)))'Image);  -- $ taint=1
   Sink (Ada.Directories.Compose ("/tmp", S));        -- $ taint=1
   Handle ("literal");
   declare
      L     : String (1 .. 10) := (others => ' ');
      Clean : String (1 .. 10) := (others => ' ');
   begin
      L (1) := S (S'First);
      Sink (L);                                         -- $ taint=1
      Sink (L (1 .. 2));                                -- $ taint=1
      Sink ("a" & L);                                   -- $ taint=1
      Clean (1) := 'x';
      Sink (Clean);
   end;
   Sink (Copy_Elements (S));                         -- $ taint=1
   Sink (Copy_Of (S));                               -- $ taint=1
end Test;
