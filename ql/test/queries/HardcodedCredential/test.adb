procedure Test is
   Api_Key  : constant String := "sk_live_abcdef123456";  --  BAD
   Password : constant String := "";                      --  OK: empty
   Count    : constant Integer := 5;                       --  OK: not a string
begin
   null;
end Test;
