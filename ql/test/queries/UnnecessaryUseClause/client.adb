with Geometry; use Geometry;   -- not reported: Reset is used directly
with Tools; use Tools;         -- reported: unused
procedure Client is
   use Geometry;               -- reported: nested
begin
   Reset;
end Client;
