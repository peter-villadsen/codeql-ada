with Ada.Containers.Ordered_Multisets;
package Sets is
   --  a-coormu.ads, extracted as a predefined pseudo-source, has marker
   --  comments of its own: not reported (D-026).
   package Int_Sets is new Ada.Containers.Ordered_Multisets (Integer);
end Sets;
