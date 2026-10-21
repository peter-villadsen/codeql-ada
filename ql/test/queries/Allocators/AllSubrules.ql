/**
 * Every predicate of `codeql.ada.adacontrol.Allocators`, for the shipped query's test
 * sources: the allocated type and its category, `anonymous`, `inconsistent`.
 */

import ada
import codeql.ada.adacontrol.Allocators

from Allocator a, string what
where
  a.fromSource() and
  (
    exists(Type t | Allocators::allocates(a, t) | what = "allocates " + t.getName())
    or
    exists(string c |
      c = ["()", "access", "array", "delta", "digits", "mod", "range", "record", "tagged"] and
      Allocators::allocatesCategory(a, c) and
      what = "category " + c
    )
    or
    Allocators::isAnonymous(a) and what = "anonymous"
    or
    Allocators::isInconsistent(a) and what = "inconsistent"
  )
select a, what
