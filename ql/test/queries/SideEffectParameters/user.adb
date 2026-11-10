with Counters; use Counters;
procedure User is
   X : Integer;
begin
   Record_Pair (Next_Id, Next_Seq);              -- reported: same group
   Record_Pair (Next_Id, Next_Id);               -- reported: same function
   Record_Pair (Random, Random);                 -- reported
   Record_Pair (Next_Id, Random);                -- not reported: different groups
   Record_Pair (Next_Id, Pure_Value (3));        -- not reported: one side effect
   X := Next_Id + Next_Seq;                      -- reported: operator
   Record_Pair (Pure_Value (Next_Id), Next_Seq); -- reported: in nested actuals
   Record_Pair (Pure_Value (Next_Id + Random), 1); -- not reported
   X := Pure_Value (Pure_Value (Next_Id));       -- not reported: nested, ordered
   declare
      package P is new Pair (Next_Id + 0, Next_Seq * 1);  -- reported: instantiation
   begin
      X := P.Sum;
   end;
end User;
