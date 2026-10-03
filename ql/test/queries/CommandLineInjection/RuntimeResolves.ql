/**
 * Guards CommandLineInjection's test against going silently blind (D-026): without
 * a GNAT runtime at extraction, neither `Argument` nor `Spawn` resolves and the
 * query reports nothing. Counts the fixture's calls that resolve to each; a name
 * with no such call has no row, and the test fails.
 */

import ada
import codeql.ada.dataflow.DataFlow

from string name
where name = ["Ada.Command_Line.Argument", "System.OS_Lib.Spawn"]
select name,
  strictcount(Raw::CallExpr c |
    c.(AdaNode).fromSource() and
    DataFlow::getCallTarget(c).(BasicDecl).getUltimateDecl().(BasicDecl).hasQualifiedName(name)
  )
