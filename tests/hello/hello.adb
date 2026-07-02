with Ada.Text_IO;
with Greeter;

procedure Hello is
begin
   Ada.Text_IO.Put_Line ("Hello, CodeQL!");
   Greeter.Greet ("Ada");
end Hello;
