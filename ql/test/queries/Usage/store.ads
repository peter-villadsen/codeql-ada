package Store is
   Limit : constant Integer := 10;      -- read
   Unused_Max : constant Integer := 99; -- reported: not read
   type Count is range 0 .. 100;
   type Orphan is range 0 .. 1;          -- reported: not used
   procedure Put (X : Count);
   procedure Forgotten;                  -- reported: not called, from_spec
   function Double (X : Integer) return Integer;  -- reported: accessed
   type Int_Fn is access function (X : Integer) return Integer;
   Fail : exception;                     -- reported: raised, not handled
   Caught : exception;
   generic
   procedure Gen;                        -- reported: not instantiated
   protected Guard is                    -- reported: called
      procedure Touch;
   end Guard;
private
   Hidden : Integer := 0;
end Store;
