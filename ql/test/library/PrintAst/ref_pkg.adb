package body Ref_Pkg is
   procedure Move (S : in out Shape; By : Integer) is
   begin
      S.Id := S.Id + By;
   end Move;

   function Area (S : Shape) return Integer is
   begin
      return S.Id * 2;
   end Area;
end Ref_Pkg;
