--  Missing is not available, so Libadalang cannot resolve these formals' types and
--  its own spec-to-body pairing fails; the extractor pairs them by syntax.
with Missing;
package Broken is
   procedure Put (Text : String; Level : Missing.Level := Missing.Info);
   procedure Log (X : Missing.A);   --  same formal names and modes as the next:
   procedure Log (X : Missing.B);   --  the type texts decide
end Broken;
