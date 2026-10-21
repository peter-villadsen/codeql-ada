/**
 * Every subrule of `codeql.ada.adacontrol.Dependencies`, for the shipped query's test
 * sources: `with` (through renamings), `public_child`, `private_child`, and the
 * counters `raw`, `direct`, `parent`.
 */

import ada
import codeql.ada.adacontrol.Dependencies

from CompilationUnit cu, string what
where
  cu.fromSource() and
  (
    exists(Name n, BasicDecl unit |
      Dependencies::withOf(cu, n, unit) and
      unit.hasQualifiedName("Ada.Text_IO") and
      what = "with Ada.Text_IO as " + n.getText()
    )
    or
    exists(Name n, boolean isPrivate |
      Dependencies::dependsOnOwnChild(cu, n, isPrivate) and
      what = "own child " + n.getText() + " private: " + isPrivate
    )
    or
    exists(Dependencies::unitOf(cu)) and
    what =
      "raw " + Dependencies::rawCount(cu) + ", direct " + Dependencies::directCount(cu) +
        ", parent " + Dependencies::parentCount(cu)
  )
select cu, what
