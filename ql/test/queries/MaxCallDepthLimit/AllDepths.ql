/**
 * Every call's depth from `codeql.ada.adacontrol.MaxCallDepth`, for the shipped
 * query's test sources, with whether it is exact and whether its target is recursive.
 */

import ada
import codeql.ada.adacontrol.MaxCallDepth

from Call c, string exact, string rec
where
  c.fromSource() and
  exists(MaxCallDepth::callDepth(c)) and
  (if MaxCallDepth::isExactCall(c) then exact = "exact" else exact = "minimum") and
  if MaxCallDepth::isRecursive(c.getTarget()) then rec = "recursive" else rec = ""
select c, MaxCallDepth::callDepth(c), exact, rec
