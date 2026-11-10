with System;
package Init is
   type Ptr is access Integer;
   type Lim is limited record
      X : Integer;
   end record;

   procedure Get (V : out Integer);
   procedure Good_Out (V : out Integer; Flag : Boolean);
   procedure Late_Out (V : out Integer);
   procedure Early_Return (V : out Integer; Flag : Boolean);
   procedure Never_Out (V : out Integer);
   procedure Only_Raise (V : out Integer);
   procedure Branch_Out (V : out Integer; Flag : Boolean);
   procedure Half_Branch (V : out Integer; Flag : Boolean);
   procedure Case_Out (V : out Integer; K : Natural);
   procedure Variables (N : Integer);
   procedure Skipped;
   type Pair is record
      A, B : Integer;
   end record;
   type Arr is array (1 .. 4) of Integer;
   procedure By_Parts (P : out Pair; N : Integer);
   procedure Bounds (N : Integer);
   function Find (N : Integer; Found : out Integer) return Boolean;
   function Via_Function (N : Integer) return Integer;
   procedure Aliased_Var;
   procedure Record_Read (P : out Pair);
   function In_Declaration (N : Integer; Found : out Integer) return Integer;
   procedure Overlay (Where : System.Address);
   function Jumps (N : Integer) return Integer;
end Init;
