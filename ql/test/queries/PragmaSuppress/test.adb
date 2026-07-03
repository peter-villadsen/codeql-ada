procedure Test is
   pragma Suppress (Range_Check);       --  BAD
   pragma Suppress (All_Checks);        --  BAD
   pragma Optimize (Time);              --  fine
   X : Integer := 0;
begin
   X := X + 1;
end Test;
