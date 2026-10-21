package Empty is
   X : Integer := 0;
private                                 --  BAD: empty private part
   pragma Warnings (Off);
end Empty;
