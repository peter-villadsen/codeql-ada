with Used;
with Parent.Child;
procedure Main is                                   --  unreferenced, but a subprogram: a main
begin
   Used.X := Parent.Child.W;
end Main;
