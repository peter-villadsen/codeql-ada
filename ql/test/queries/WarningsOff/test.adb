procedure Test is
   X : Integer;
   pragma Warnings (Off);            --  BAD
   pragma Warnings (Off, X);         --  fine, restricted to X
   pragma Warnings (Off, "unused");  --  fine, restricted to a specific warning
begin
   X := 0;
end Test;
