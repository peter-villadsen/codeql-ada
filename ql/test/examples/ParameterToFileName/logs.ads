package Logs is
   procedure Open_Log (File_Name : String);  --  public: its caller picks the file
   procedure Rotate;
private
   procedure Reopen (Name : String);         --  private: not part of the interface
end Logs;
