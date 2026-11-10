with Geometry;
procedure Types_User is
   use type Geometry.Length;   -- not reported: "+" is used
   use type Geometry.Color;    -- reported: unused
   L : Geometry.Length := 3;
begin
   L := L + 1;
end Types_User;
