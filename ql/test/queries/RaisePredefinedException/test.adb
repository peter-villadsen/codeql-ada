procedure Test is
   My_Error : exception;
begin
   raise Constraint_Error;            --  BAD
   raise Standard.Program_Error;      --  BAD
   raise My_Error;                    --  fine, user-defined
end Test;
