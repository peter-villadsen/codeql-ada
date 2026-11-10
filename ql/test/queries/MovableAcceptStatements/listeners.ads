with Missing_Pkg;

package Listeners is
   task Listener is
      entry Listen (FD : Missing_Pkg.Descriptor);  -- a type the extractor cannot see
   end Listener;
end Listeners;
