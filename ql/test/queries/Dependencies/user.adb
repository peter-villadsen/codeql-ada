with Parent.Pub;                 --  fine: not a child of User
with Text_IO;                    --  a renaming of Ada.Text_IO
procedure User is
begin
   Text_IO.Put_Line (Integer'Image (Parent.Pub.Y));
end User;
