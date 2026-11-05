package Devices is
   type Mode is (Fast, Slow);
   Default_Port : constant := 8;

   procedure Init (Port : Integer; M : Mode := Fast);
   procedure Initialize (Buffer : out String);
   procedure Init_Other (Port : Integer);             --  not an initialization procedure by default
   procedure Initialize_Both (A : in out Integer);    --  fits neither pattern
end Devices;
