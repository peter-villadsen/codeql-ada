/**
 * Every subrule of `codeql.ada.adacontrol.WithClauses`, for the shipped query's test
 * sources: `multiple_names`, the kinds, `reduceable` (redundant, ancestor, movable) and
 * `inherited`.
 */

import ada
import codeql.ada.adacontrol.WithClauses

from AdaNode n, string what
where
  n.fromSource() and
  (
    WithClauses::hasMultipleNames(n) and what = "multiple_names"
    or
    what = "kind " + WithClauses::withKind(n)
    or
    exists(Name earlier | WithClauses::isRedundant(_, n, earlier) | what = "redundant")
    or
    WithClauses::withsAncestor(_, n) and what = "ancestor"
    or
    exists(string to | WithClauses::isMovable(_, n, to) | what = "movable to " + to)
    or
    exists(CompilationUnit unitCu | WithClauses::inheritsWith(_, n, unitCu) | what = "inherited")
  )
select n, what
