with Ada.Command_Line;

package body My_App is
   package body Db is
      procedure Execute (Query : String) is null;
   end Db;

   package body Validate is
      function Sanitize (S : String) return String is (S);
   end Validate;

   --  a helper the value passes through on its way to Execute
   procedure Run_Query (Q : String) is
   begin
      Db.Execute (Q);                                --  BAD: from the command line, via Main
   end Run_Query;

   package body Server is
      procedure Handle_Request (Body_Text : String) is
      begin
         Db.Execute ("SELECT " & Body_Text);         --  BAD: request input
         Db.Execute (Validate.Sanitize (Body_Text)); --  fine: sanitized
      end Handle_Request;
   end Server;

   procedure Main is
   begin
      Run_Query (Ada.Command_Line.Argument (1));
      Db.Execute ("SELECT 1");                       --  fine: a constant
   end Main;
end My_App;
