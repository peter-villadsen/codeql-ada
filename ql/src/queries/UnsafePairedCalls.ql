/**
 * @name Paired calls not in the safe pattern
 * @description A lock must be released on every path, exceptions included. AdaControl
 *              rule `Unsafe_Paired_Calls`, for the procedures named with the data
 *              extension `pairedCalls` (opening, closing, lock type): the opening call
 *              must be the first statement of a handled sequence, the closing call its
 *              last, every `return`, `exit` or `goto` leaving the sequence must follow a
 *              closing call, and the sequence must have a `when others` handler, every
 *              handler closing. With a lock type, the calls are paired by the lock
 *              they pass. With no row, nothing is reported. Left out: openings and
 *              closings wrapped in an `if` on a constant (`Conditionals_Allowed`).
 *              See `codeql.ada.adacontrol.UnsafePairedCalls` (`docs/adacontrol.md`).
 * @id ada/unsafe-paired-calls
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.UnsafePairedCalls

from Raw::CallStmt s, string msg
where
  s.fromSource() and
  (
    UnsafePairedCalls::unsafeOpening(s, _) and
    msg =
      "This opening call " +
        concat(string reason | UnsafePairedCalls::unsafeOpening(s, reason) | reason, "; ") + "."
    or
    UnsafePairedCalls::unsafeClosing(s) and
    msg = "This closing call does not close an opening call in the safe pattern."
  )
select s, msg
