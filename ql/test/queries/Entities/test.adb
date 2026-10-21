with Debug;
package body Test is
   procedure Log (Msg : String) renames Debug.Trace;
   procedure Dump_Int is new Debug.Dump (Integer);

   type Int_Ptr is access all Integer;
   X : aliased Integer := 0;
   P : Int_Ptr := X'Unchecked_Access;           --  BAD
   Q : Int_Ptr := X'Access;                     --  fine

   procedure Run is
      Y : aliased Integer := 1;
      R : Int_Ptr := Y'Unrestricted_Access;     --  BAD
   begin
      Debug.Trace ("direct");                   --  a use of Debug.Trace
      Log ("renamed");                          --  a use of Debug.Trace, renamed
      Dump_Int (3);                             --  a use of an instance of Debug.Dump
      declare
      begin
         Debug.Trace ("in a block");
      end;
   end Run;
begin
   Debug.Trace ("in the package body");
end Test;
