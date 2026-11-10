/**
 * @name Call outside elaboration
 * @description Some subprograms are meant to be called only while library packages are
 *              elaborated (registering handlers, building tables), and some projects
 *              allocate only then, so that memory use is fixed once the program runs.
 *              AdaControl rule `Not_Elaboration_Calls`, for the subprograms (and `new`
 *              for allocators) named with the data extension `notElaborationCall`: a
 *              call or allocator that may run outside elaboration, in a body or in a
 *              subprogram called from one. With no row, nothing is reported. See
 *              `codeql.ada.adacontrol.NotElaborationCalls` (`docs/adacontrol.md`).
 * @id ada/not-elaboration-calls
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.NotElaborationCalls
import codeql.ada.adacontrol.Settings

from AdaNode site, string msg
where
  site.fromSource() and
  (
    exists(Subprogram s, string name |
      notElaborationCall(name) and
      s.hasQualifiedName(name) and
      NotElaborationCalls::callOutside(site, s) and
      msg = "This call of " + s.getName() + " may happen after elaboration."
    )
    or
    notElaborationCall(any(string n | n.toLowerCase() = "new")) and
    NotElaborationCalls::allocatorOutside(site) and
    msg = "This allocator may run after elaboration."
  )
select site, msg
