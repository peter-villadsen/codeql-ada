procedure Test is
   Api_Key           : constant String := "sk_live_abcdef123456";  --  BAD
   Password          : constant String := "";                      --  OK: empty
   Count             : constant Integer := 5;                       --  OK: not a string
   Auth_Token        : constant String := "eyJhbGciOiJIUzI1NiJ9";  --  BAD
   Token             : constant String := "ghp_0123456789abcdef";  --  BAD
   Token_Kind_Name_5 : constant String := "identifier";            --  OK: a lexer's token
   Protected_Token   : constant String := "protected";             --  OK: a lexer's token
   Access_Token      : constant String := "access";                --  OK: a lexer's keyword token
begin
   null;
end Test;
