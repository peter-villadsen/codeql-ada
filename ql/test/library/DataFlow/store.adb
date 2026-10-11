package body Store is
   function Source (Id : Integer) return Integer is (Id);
   procedure Sink (X : Integer) is null;

   procedure Set (X : Integer) is
   begin
      G := X;
   end Set;

   --  Flow between subprograms through a package variable ignores the order of the
   --  calls: every store into G reaches this read, also those made after Show runs
   --  (40, 42) or in a subprogram that is never called (43).
   procedure Show is
   begin
      Sink (G);  -- $ flow=41 SPURIOUS: flow=40 flow=42 flow=43
   end Show;

   procedure Local is
   begin
      G := Source (43);
      Sink (G);  -- $ flow=43
   end Local;
end Store;
