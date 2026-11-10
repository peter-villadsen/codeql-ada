/**
 * The elaboration analysis of `codeql.ada.adacontrol.NotElaborationCalls`, for the
 * shipped query's test sources: which subprograms may run outside elaboration, and
 * which calls and allocators.
 */

import ada
import codeql.ada.adacontrol.NotElaborationCalls

from AdaNode n, string what
where
  n.fromSource() and
  (
    NotElaborationCalls::mayRunOutside(n) and what = "may run outside elaboration"
    or
    NotElaborationCalls::callOutside(n, _) and what = "call outside elaboration"
    or
    NotElaborationCalls::allocatorOutside(n) and what = "allocator outside elaboration"
    or
    (n instanceof Call or n instanceof Raw::Allocator) and
    NotElaborationCalls::isElaborationCode(n) and
    what = "elaboration code"
  )
select n, what
