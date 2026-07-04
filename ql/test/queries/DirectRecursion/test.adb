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
