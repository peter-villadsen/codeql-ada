with Ada.Text_IO;

package body Greeter is

   procedure Greet (Name : String) is
   begin
      Ada.Text_IO.Put_Line ("Greetings, " & Name & "!");
   end Greet;

end Greeter;
