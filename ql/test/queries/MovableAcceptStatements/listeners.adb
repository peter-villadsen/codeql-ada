package body Listeners is
   task body Listener is
      Listen_FD : Missing_Pkg.Descriptor;
   begin
      loop
         accept Listen (FD : Missing_Pkg.Descriptor) do
            Listen_FD := FD;                     -- parameter, unresolved
         end Listen;
      end loop;
   end Listener;
end Listeners;
