package body Init is

   procedure Get (V : out Integer) is
   begin
      V := 1;                              -- safe
   end Get;

   procedure Good_Out (V : out Integer; Flag : Boolean) is
   begin
      if Flag then
         V := 1;
         return;                           -- assigned before this return
      end if;
      V := 2;
      for I in 1 .. 3 loop
         null;
      end loop;
   end Good_Out;

   procedure Late_Out (V : out Integer) is  -- V: not assigned before the loop
   begin
      for I in 1 .. 3 loop
         V := I;
      end loop;
   end Late_Out;

   procedure Early_Return (V : out Integer; Flag : Boolean) is
   begin
      if Flag then
         return;                           -- returns before V is assigned
      end if;
      V := 0;
   end Early_Return;

   procedure Never_Out (V : out Integer) is  -- V: never assigned
   begin
      null;
   end Never_Out;

   procedure Only_Raise (V : out Integer) is  -- not checked before raise
   begin
      raise Program_Error;
   end Only_Raise;

   procedure Branch_Out (V : out Integer; Flag : Boolean) is
   begin
      if Flag then                         -- assigns V in every branch
         V := 1;
      else
         Get (V);
      end if;
      loop
         exit;
      end loop;
   end Branch_Out;

   procedure Half_Branch (V : out Integer; Flag : Boolean) is  -- V: only one branch
   begin
      if Flag then
         V := 1;
      end if;
      loop
         exit;
      end loop;
   end Half_Branch;

   procedure Case_Out (V : out Integer; K : Natural) is
   begin
      case K is                            -- assigns V in every alternative
         when 0 => V := 0;
         when others => V := 1;
      end case;
      while V > 10 loop
         V := V - 1;
      end loop;
   end Case_Out;

   procedure Variables (N : Integer) is
      A : Integer;                         -- assigned up front: safe
      B : Integer;                         -- assigned only in the loop
      C : Integer;                         -- read before assigned
      D : Integer := 0;                    -- redundant: replaced before any read
      E : Integer := 0;                    -- used before replaced: needed
      F : Integer;                         -- never read: left to ada/unused-local
      R : Lim;
   begin
      A := N;
      C := C + 1;
      D := N;
      E := E + N;
      for I in 1 .. N loop
         B := I;
         A := A + B + C + D + E;
      end loop;
      F := 1;
      R.X := A;
   end Variables;

   procedure Skipped is
      P : Ptr;                             -- access: initialized to null
      L : Lim;                             -- limited: cannot be assigned whole
   begin
      for I in 1 .. 2 loop
         P := new Integer'(I);
         L.X := P.all;
      end loop;
   end Skipped;

   procedure By_Parts (P : out Pair; N : Integer) is
      Q : Pair;
   begin
      P.A := N;                            -- assigned by parts: not a read
      P.B := P.A + 1;                      -- whole assignments only: a read of P
      Q.A := 0;
      Q.B := Q.A;                          -- likewise
      P := Q;
   end By_Parts;

   procedure Bounds (N : Integer) is
      A : Arr;
      I : Integer;
   begin
      I := A'First;                        -- 'First does not read A
      A (I) := N;
      A (A'Last) := A (I);                 -- read of A after a part is assigned
      for J in A'Range loop
         null;
      end loop;
   end Bounds;

   function Find (N : Integer; Found : out Integer) return Boolean is
   begin
      Found := N;
      return N > 0;
   end Find;

   function Via_Function (N : Integer) return Integer is
      X : Integer;
   begin
      if Find (N, X) then                  -- the condition assigns X
         return X;
      end if;
      return Integer'Max (X, 0);           -- likewise
   end Via_Function;

   procedure Aliased_Var is
      X : aliased Integer;                 -- assigned through X'Access: not checked
      P : constant Ptr := X'Unchecked_Access;
   begin
      P.all := 1;
      Get (P.all);
      X := X + 1;
   end Aliased_Var;

   procedure Record_Read (P : out Pair) is
      Q : Pair;                            -- a record: may have defaults, not checked
   begin
      P := Q;
   end Record_Read;

   function In_Declaration (N : Integer; Found : out Integer) return Integer is
      OK : constant Boolean := Find (N, Found);  -- assigns Found
   begin
      if not OK then
         return 0;
      end if;
      return Found;
   end In_Declaration;

   procedure Overlay (Where : System.Address) is
      V : Integer with Import, Address => Where;  -- an overlay: not checked
      W : Integer;
   begin
      W := V + W;                          -- W is read before it is assigned
   end Overlay;

   function Jumps (N : Integer) return Integer is
      L : Integer;
   begin
      if N < 0 then
         raise Constraint_Error;
      elsif N = 0 then
         return 0;
      else
         L := N;
      end if;
      return L;                            -- assigned on every path that gets here
   end Jumps;

end Init;
