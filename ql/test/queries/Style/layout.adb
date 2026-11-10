package body Layout is
   pragma suppress (Range_Check);           -- casing_pragma

   procedure put (X : Integer) is           -- casing_identifier (spec says Put)
      Y : Integer := 0; Z : Integer := 2;   -- multiple_elements
   begin
      Y := X + 1;
      Z := Integer'image (Y)'Length;        -- casing_attribute
      Y := max_count;                       -- casing_identifier
   end Put;

   procedure Get (X : in Integer; Y : out Integer) is
   begin
      Y := X * 3;
   end;                                     -- no_closing_name

   procedure Ref (P : access Integer) is
   begin
      P.all := 0;
   end Ref;
end Layout;
