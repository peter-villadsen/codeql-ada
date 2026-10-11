package AWS.Status is
   type Data is private;
   function Parameter (D : Data; Name : String; N : Positive := 1) return String;
   function URI (D : Data) return String;
private
   type Data is null record;
end AWS.Status;
