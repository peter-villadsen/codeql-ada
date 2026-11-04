package body Shared is
   Good       : Integer := 0;          --  fine: one reader, one writer
   Alone      : Integer := 0;          --  fine: one subprogram reads and writes it
   Written    : Integer := 0;          --  BAD: two writers
   Mixed      : Integer := 0;          --  BAD: read and written by one, read by another
   In_Nested  : Integer := 0;          --  BAD: accessed from a nested subprogram
   At_Elab    : Integer := 0;          --  BAD: accessed in the package's statements
   By_Out     : Integer := 0;          --  BAD: written through an out parameter, and by another
   Guarded    : Integer := 0;          --  fine: only the protected object's operations
   Two_Objects : Integer := 0;         --  BAD: two protected objects
   By_Task    : Integer := 0;          --  fine: the accept statements of one task
   Typed_PO   : Integer := 0;          --  BAD: the operations of a protected type
   Limit      : constant Integer := 10; --  fine: a constant

   procedure Set_Good (V : Integer) is
   begin
      Good := V;
   end Set_Good;

   function Get_Good return Integer is (Good + Limit + Spec_Var);

   procedure Bump_Alone is
   begin
      Alone := Alone + 1;
   end Bump_Alone;

   procedure Two_Writers_A is
   begin
      Written := 1;
   end Two_Writers_A;

   procedure Two_Writers_B is
   begin
      Written := 2;
   end Two_Writers_B;

   procedure Read_Write is
   begin
      Mixed := Mixed + 1;
   end Read_Write;

   function Also_Reads return Integer is (Mixed);

   procedure Outer is
      procedure Inner is
      begin
         In_Nested := 1;
      end Inner;
   begin
      Inner;
   end Outer;

   procedure Set (X : out Integer) is
   begin
      X := 0;
   end Set;

   procedure Uses_Out is
   begin
      Set (By_Out);
   end Uses_Out;

   procedure Uses_Spec is
   begin
      By_Out := 3;
      Spec_Var := 1;
   end Uses_Spec;

   protected Lock is
      procedure Put (V : Integer);
      function Take return Integer;
      entry Wait;
   end Lock;

   protected body Lock is
      procedure Put (V : Integer) is
      begin
         Guarded := V;
         Two_Objects := V;
      end Put;
      function Take return Integer is (Guarded);
      entry Wait when True is
      begin
         Guarded := Guarded + 1;
      end Wait;
   end Lock;

   protected Other_Lock is
      procedure Put (V : Integer);
   end Other_Lock;

   protected body Other_Lock is
      procedure Put (V : Integer) is
      begin
         Two_Objects := V;
      end Put;
   end Other_Lock;

   protected type Lock_Type is
      procedure Put (V : Integer);
   end Lock_Type;

   protected body Lock_Type is
      procedure Put (V : Integer) is
      begin
         Typed_PO := V;
      end Put;
   end Lock_Type;

   task Worker is
      entry Store (V : Integer);
      entry Fetch (V : out Integer);
   end Worker;

   task body Worker is
   begin
      loop
         select
            accept Store (V : Integer) do
               By_Task := V;
            end Store;
         or
            accept Fetch (V : out Integer) do
               V := By_Task;
            end Fetch;
         or
            terminate;
         end select;
      end loop;
   end Worker;

begin
   At_Elab := 1;
end Shared;
