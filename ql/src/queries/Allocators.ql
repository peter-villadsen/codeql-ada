/**
 * @name Questionable allocator
 * @description An allocator of an anonymous access type gets the accessibility rules
 *              of anonymous access types, which are hard to follow; an allocator naming
 *              a different subtype than its access type designates (`new Natural` for
 *              `access Positive`) checks two constraints and misleads the reader.
 *              AdaControl rule `Allocators`, modifiers `anonymous` and `inconsistent`.
 *              Allocators of given types or categories, and `not`, are in
 *              `codeql.ada.adacontrol.Allocators` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/allocators
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Allocators

from Allocator a, string msg
where
  a.fromSource() and
  (
    Allocators::isAnonymous(a) and
    msg = "Allocator of an anonymous access type: declare a named access type."
    or
    Allocators::isInconsistent(a) and
    msg =
      "Allocator of subtype " + Allocators::allocatedSubtypeMark(a).getText() +
        ", but its access type designates another subtype."
  )
select a, msg
