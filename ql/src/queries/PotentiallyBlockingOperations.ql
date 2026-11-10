/**
 * @name Potentially blocking operation in protected operation
 * @description A protected operation must not perform a potentially blocking operation
 *              (Ada RM 9.5.1): a `delay`, `select`, `accept` or `abort` statement, an
 *              entry call, the creation of a task, or a call of an input-output
 *              subprogram. It holds the protected object's lock while it blocks, or
 *              raises `Program_Error`. AdaControl rule `Potentially_Blocking_Operations`:
 *              operations the protected operations perform directly or through the
 *              subprograms they call. Further blocking subprograms are named with the
 *              data extension `blockingSubprogram`. Left out: external calls back to the
 *              same protected object, and remote calls. See
 *              `codeql.ada.adacontrol.PotentiallyBlockingOperations` (`docs/adacontrol.md`).
 * @id ada/potentially-blocking-operations
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags correctness concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.PotentiallyBlockingOperations

from AdaNode n, string kind, Raw::ProtectedBody p
where
  n.fromSource() and
  PotentiallyBlockingOperations::blocking(p, _, n, kind)
select n, "This " + kind + " is potentially blocking, and runs in an operation of protected $@.",
  p, p.getName().getName().getText()
