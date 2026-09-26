with Ada.Finalization;
package Ctl is
   --  a-finali.ads, extracted as a predefined pseudo-source because Controlled
   --  resolves into it, contains a bare pragma Warnings (Off): not reported (D-026).
   type Res is new Ada.Finalization.Controlled with null record;
end Ctl;
