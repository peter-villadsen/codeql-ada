package My_App is
   package Db is
      procedure Execute (Query : String);
   end Db;

   package Validate is
      function Sanitize (S : String) return String;
   end Validate;

   package Server is
      procedure Handle_Request (Body_Text : String);
   end Server;

   procedure Main;
end My_App;
