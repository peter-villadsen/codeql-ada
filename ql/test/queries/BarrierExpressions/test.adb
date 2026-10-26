procedure Test is
   type Level is range 0 .. 10;
   type Bits is array (1 .. 4) of Boolean;
   type Pair is record
      A, B : Boolean;
   end record;
   type Flag_Access is access Boolean;

   Max      : constant := 5;
   Global   : Boolean := False;
   G_Access : Flag_Access := new Boolean'(True);

   function Ready return Boolean is (True);
   function "and" (L : Level; R : Boolean) return Boolean is (R);

   protected type Buffer is
      entry Simple;
      entry Literal;
      entry Non_Boolean;
      entry Compare;
      entry Logic;
      entry Not_Op;
      entry Arith;
      entry Member;
      entry Attr_Count;
      entry Attr_Func;
      entry Index;
      entry Variable;
      entry Call_Ext;
      entry Call_Local;
      entry Deref;
      entry Conv;
      entry Qual;
      entry Arr_Agg;
      entry Rec_Agg;
      entry Alloc;
      entry User_Op;
      entry Named;
      entry Family (Level);
   private
      function Is_Open return Boolean;
      Open  : Boolean := False;
      Count : Level := 0;
      Flags : Bits := (others => False);
      Both  : Pair := (False, False);
      Ptr   : Flag_Access;
   end Buffer;

   protected body Buffer is
      function Is_Open return Boolean is (Open);

      entry Simple when Open is begin null; end;                       --  fine: a Boolean component
      entry Literal when True is begin null; end;                      --  fine: a literal
      entry Non_Boolean when Count = 0 is begin null; end;             --  any_component, comparison
      entry Compare when Count > 0 is begin null; end;                 --  any_component, comparison
      entry Logic when Open and then Open is begin null; end;          --  logical
      entry Not_Op when not Open is begin null; end;                   --  logical
      entry Arith when Count + 1 > 2 is begin null; end;               --  any_component, comparison, arithmetic
      entry Member when Count in 1 .. 3 is begin null; end;            --  any_component, comparison
      entry Attr_Count when Simple'Count = 0 is begin null; end;       --  value attribute, comparison
      entry Attr_Func when Level'Succ (Count) = 1 is begin null; end;  --  function attribute, any_component, comparison
      entry Index when Flags (1) is begin null; end;                   --  any_component, indexing
      entry Variable when Global is begin null; end;                   --  any_variable
      entry Call_Ext when Ready is begin null; end;                    --  a call
      entry Call_Local when Is_Open is begin null; end;                --  local_function
      entry Deref when Ptr.all is begin null; end;                     --  any_component, dereference
      entry Conv when Boolean (Open) is begin null; end;               --  conversion
      entry Qual when Boolean'(Open) is begin null; end;               --  conversion
      entry Arr_Agg when Flags = (True, True, True, True) is begin null; end;  --  any_component, comparison, array aggregate
      entry Rec_Agg when Both = (True, False) is begin null; end;      --  any_component, comparison, record aggregate
      entry Alloc when new Boolean'(Open) = G_Access is begin null; end;  --  allocation, conversion, comparison, any_variable
      entry User_Op when Count and Open is begin null; end;            --  any_component, a call
      entry Named when Count < Max is begin null; end;                 --  any_component, comparison; a named number is fine
      entry Family (for I in Level) when I = Count is begin null; end; --  comparison, any_component; the family index is fine
   end Buffer;
begin
   null;
end Test;
