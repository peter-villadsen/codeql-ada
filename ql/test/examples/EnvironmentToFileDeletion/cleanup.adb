with Ada.Directories;
with Ada.Environment_Variables;

procedure Cleanup is
   function Work_Dir return String is (Ada.Environment_Variables.Value ("WORK_DIR"));

   procedure Remove (Path : String) is
   begin
      Ada.Directories.Delete_File (Path);  --  BAD: from WORK_DIR, via Work_Dir and Remove
   end Remove;

   Lock_File : constant String := "/tmp/cleanup.lock";
begin
   Remove (Work_Dir & "/cache.dat");
   Remove (Lock_File);                     --  fine on its own: a constant
   Ada.Directories.Delete_Tree (Ada.Environment_Variables.Value ("TMP_TREE"));  --  BAD
end Cleanup;
