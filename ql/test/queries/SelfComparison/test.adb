procedure Test (X : Integer; Y : Integer) is
   Flag : Boolean;
begin
   Flag := X = X;
   Flag := X <= X;
   Flag := X = Y;
   Flag := X = 0;
end Test;
