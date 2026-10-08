procedure Rec1 (N : Integer) is      --  spec-less, recursive: BAD
begin
   if N > 0 then
      Rec1 (N - 1);
   end if;
end Rec1;

procedure Rec2 (N : Integer);
procedure Rec2 (N : Integer) is      --  spec+body, recursive: BAD
begin
   if N > 0 then
      Rec2 (N - 1);
   end if;
end Rec2;

procedure NonRec (N : Integer) is    --  not recursive: fine
begin
   null;
end NonRec;

procedure Outer is
   procedure Over (N : Integer);
   procedure Over (S : String);

   procedure Over (N : Integer) is  --  calls the other overload: fine
   begin
      Over (Integer'Image (N));
   end Over;

   procedure Over (S : String) is
   begin
      null;
   end Over;
begin
   Over (1);
end Outer;

--  Shapes the call graph sees and a CallExpr-only search did not (Phase 12, Task 12.4).
procedure Shapes is
   Count : Natural := 3;

   procedure Tick;                   --  parameterless, called without parentheses: BAD
   procedure Tick is
   begin
      if Count > 0 then
         Count := Count - 1;
         Tick;
      end if;
   end Tick;

   function Fact (N : Natural) return Natural is      --  expression function: BAD
     (if N = 0 then 1 else N * Fact (N - 1));

   procedure Via_Renaming (N : Natural);
   procedure Again (N : Natural) renames Via_Renaming;
   procedure Via_Renaming (N : Natural) is            --  through a renaming: BAD
   begin
      if N > 0 then
         Again (N - 1);
      end if;
   end Via_Renaming;

   procedure Outer_Proc is
      procedure Inner_Proc is                         --  calls its enclosing subprogram: fine
      begin
         Outer_Proc;
      end Inner_Proc;
   begin
      null;
   end Outer_Proc;
begin
   Tick;
   Count := Fact (3);
   Via_Renaming (2);
end Shapes;

generic
   type T is private;
procedure Gen_Rec (N : Natural; X : T);
procedure Gen_Rec (N : Natural; X : T) is   --  recursive generic: BAD
begin
   if N > 0 then
      Gen_Rec (N - 1, X);
   end if;
end Gen_Rec;
