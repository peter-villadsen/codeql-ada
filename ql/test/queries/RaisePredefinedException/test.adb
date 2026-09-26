procedure Test is
   My_Error : exception;
   Oops : exception renames Constraint_Error;
begin
   raise Constraint_Error;            --  BAD
   raise Standard.Program_Error;      --  BAD
   raise My_Error;                    --  fine, user-defined
   raise Numeric_Error;               --  BAD
   raise Oops;                        --  BAD, a renaming of Constraint_Error
   declare
      Constraint_Error : exception;   --  a user exception shadowing Standard's
   begin
      raise Constraint_Error;         --  fine, not the predefined one
   end;
end Test;
