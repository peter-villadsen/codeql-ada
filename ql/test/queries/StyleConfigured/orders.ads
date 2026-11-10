package Orders is
   procedure Good (A : in Integer; B : in out Integer; C : out Integer; D : in Integer := 0);
   procedure Bad (C : out Integer; A : in Integer);   -- parameter_order
   generic
      with procedure Action;
      type Item is private;                         -- formal_parameter_order
   package Gen is
   end Gen;
   procedure short_name;                            -- casing_identifier titlecase
end Orders;
