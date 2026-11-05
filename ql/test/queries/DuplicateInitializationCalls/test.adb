with Devices; use Devices;
procedure Test is
   B1, B2 : String (1 .. 4);
   Port   : Integer := 3;
   A      : Integer := 0;
begin
   Init (1);
   Init (2);                        --  fine: other values
   Init (1, Fast);                  --  BAD: the same values as Init (1), Fast by default
   Init (1, Slow);                  --  fine
   Init (Port => 1);                --  BAD: the same values again, named
   Init (Default_Port);
   Init (Default_Port);             --  BAD: the same named number
   Init (Port);                     --  fine by default: not static
   Init (Port);                     --  fine: not static, so not compared
   Initialize (B1);
   Initialize (B2);                 --  fine: another variable
   Initialize (B1);                 --  fine by default: the out pattern needs the setting
   Init_Other (1);
   Init_Other (1);                  --  fine by default: not an initialization procedure
   Initialize_Both (A);
end Test;
