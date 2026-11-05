/**
 * Every predicate of `codeql.ada.adacontrol.ExceptionPropagation`, for the shipped
 * query's test sources: each body's propagation at each level, each declaration that
 * propagates and from which level, exports, call-backs and local exceptions.
 */

import ada
import codeql.ada.adacontrol.ExceptionPropagation

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(int level | level in [0 .. 3] and ExceptionPropagation::canPropagate(n, level) |
      what = "propagates at level " + level
    )
    or
    exists(int level |
      level = min(int l | ExceptionPropagation::declarationPropagates(n, l)) and
      what = "declaration propagates from level " + level
    )
    or
    exists(Subprogram s, string convention |
      ExceptionPropagation::isExported(s, convention) and n = s and what = "exported " + convention
    )
    or
    exists(Call c, Parameter p, Subprogram s |
      ExceptionPropagation::passesSubprogram(c, p, s) and
      n = c and
      what = "passes " + s.getName() + " for " + p.getName()
    )
    or
    exists(DefiningName e, AdaNode b, string reason |
      ExceptionPropagation::localExceptionEscapes(e, b, n, reason) and
      what = "local " + e.getName().getText() + " " + reason
    )
  )
select n, what
