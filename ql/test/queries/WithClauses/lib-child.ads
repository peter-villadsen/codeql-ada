with Lib;                                           --  BAD: an ancestor
with Helper;
with Helper;                                        --  BAD: twice
package Lib.Child is
   Y : Integer := Hidden.Value + Helper.Value;      --  inherited: Hidden withed by Lib only
end Lib.Child;
