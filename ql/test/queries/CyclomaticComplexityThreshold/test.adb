--  The limit is 3 here (CyclomaticComplexity.ext.yml), not 10.
package body Test is

   procedure At_Limit (A, B : Boolean) is   --  3
   begin
      if A then null; end if;
      if B then null; end if;
   end At_Limit;

   procedure Above_Limit (A, B, C : Boolean) is   --  BAD: 4
   begin
      if A then null; end if;
      if B then null; end if;
      if C then null; end if;
   end Above_Limit;

end Test;
