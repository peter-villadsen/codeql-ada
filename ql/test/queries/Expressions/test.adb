procedure Test is
   type Word is mod 2 ** 8;
   type Bits is array (1 .. 4) of Boolean;
   type Fix is delta 0.01 range -10.0 .. 10.0;
   type Rec is record
      A, B : Integer;
   end record;
   type Base is tagged record
      X : Integer;
   end record;
   type Child is new Base with record
      Y : Integer;
   end record;
   type Int_Ptr is access Integer;
   type Count is new Integer;

   function Twice (X : Integer) return Integer is (X * 2);
   procedure Set (X : out Integer) is
   begin
      X := 0;
   end Set;

   B1, B2 : Boolean := True;
   W1, W2 : Word := 1;
   A1, A2 : Bits := (others => False);
   F1, F2 : Fix := 1.0;
   R1 : Float := 1.0;
   I, J, K : Integer := 1;
   C : Count := 1;
   P : Int_Ptr := new Integer'(1);
   Arr : array (1 .. 10) of Integer := (1 .. 5 => 0, others => 1);
   Pos : array (1 .. 3) of Integer := (1, 2, others => 3);
   Rec1 : Rec := (A => 1, others => 2);
   Rec2 : Rec := Rec'(1, 2);
   Ch : Child := (Base'(X => 1) with Y => 2);
   Bs : Base := Base (Ch);
begin
   B1 := B1 and B2;                      --  and, and_boolean
   B1 := B1 or else B2;                  --  or_else
   B1 := not B1;                         --  not
   W1 := W1 xor W2;                      --  xor, xor_binary
   A1 := A1 or A2;                       --  or, or_array
   B1 := I in 1 .. 10;                   --  in
   B1 := I not in 1 .. 10;               --  not_in
   I := (if B1 then 1 elsif B2 then 2 else 3);   --  if, if_elsif
   B1 := (if B1 then B2);                --  if, if_no_else
   I := (case I is when 1 => 2, when others => 3);   --  case
   B1 := (for all E of Arr => E > 0);    --  for_all
   B1 := (for some E of Arr => E > 0);   --  for_some
   I := P.all;                           --  explicit_dereference
   Arr (1 .. 2) := (0, 0);               --  slice
   I := @ + 1;                           --  target_name, trivial_target_name
   I := Twice (J);                       --  function_call
   I := I + J * K;                       --  mixed_operators
   I := (I + J) * K;                     --  fine: parenthesized
   I := -I mod 3;                        --  mixed_operators
   B1 := F1 = F2;                        --  real_equality
   B1 := R1 /= 0.0;                      --  real_equality
   F1 := F1 * F2;                        --  fixed_multiplying_op
   I := Integer (C);                     --  type_conversion, upward_conversion
   C := Count (I);                       --  type_conversion, downward_conversion
   R1 := Float (I);                      --  type_conversion, underived_conversion
   Bs := Base (Ch);                      --  type_conversion, upward_conversion
   I := Twice (I + 1);                   --  complex_parameter
   I := "+" (I, J);                      --  prefixed_operator
   Set (Integer (C));                    --  parameter_view_conversion
end Test;
