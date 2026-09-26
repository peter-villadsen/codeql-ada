with Pkg_C;    --  fine: used below, in a statement name resolution fails on
procedure Test2 is
begin
   Pkg_C.Run (No_Such_Name);
end Test2;
