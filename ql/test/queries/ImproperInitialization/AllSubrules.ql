/**
 * Every subrule of `codeql.ada.adacontrol.ImproperInitialization`, for the shipped
 * query's test sources: AdaControl's (whole assignments only) and, marked `parts`,
 * with assignments to parts counting; targets the query skips are marked.
 */

import ada
import codeql.ada.adacontrol.ImproperInitialization

/** Gets `parts` in words. */
string mode(boolean parts) { parts = false and result = "" or parts = true and result = " (parts)" }

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(string kind, boolean parts | ImproperInitialization::notSafelyInitialized(n, _, kind, parts) |
      what = kind + " not safely initialized" + mode(parts)
    )
    or
    exists(Raw::Name t, boolean parts | ImproperInitialization::readBeforeAssign(n, t, _, parts) |
      what = "read of " + ImproperInitialization::targetName(t) + " before assignment" + mode(parts)
    )
    or
    exists(Parameter p, boolean parts | ImproperInitialization::returnBeforeAssign(n, p, _, parts) |
      what = "return before " + p.getName() + " is assigned" + mode(parts)
    )
    or
    ImproperInitialization::redundantInitializer(n, _) and what = "redundant initializer"
    or
    exists(string extra | ImproperInitialization::isSkipped(n, extra) | what = "skipped: " + extra)
  )
select n, what
