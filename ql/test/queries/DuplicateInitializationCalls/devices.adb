package body Devices is
   procedure Init (Port : Integer; M : Mode := Fast) is null;
   procedure Initialize (Buffer : out String) is
   begin
      Buffer := (others => ' ');
   end Initialize;
   procedure Init_Other (Port : Integer) is null;
   procedure Initialize_Both (A : in out Integer) is null;
end Devices;
