/**
 * Every subrule of `codeql.ada.adacontrol.ObjectDeclarations`, for the shipped query's
 * test sources: `min_integer_span`, `type` (Integer, its subtypes), `volatile_no_address`,
 * `address_not_volatile`.
 */

import ada
import codeql.ada.adacontrol.ObjectDeclarations

from ObjectDecl d, string what
where
  d.fromSource() and
  (
    what = "span " + ObjectDeclarations::integerSpan(d)
    or
    exists(Type t, boolean exact |
      t.hasQualifiedName("Standard.Integer") and
      ObjectDeclarations::hasType(d, t, exact) and
      what = "type Integer (exact: " + exact + ")"
    )
    or
    ObjectDeclarations::volatileNoAddress(d) and what = "volatile_no_address"
    or
    ObjectDeclarations::addressNotVolatile(d) and what = "address_not_volatile"
  )
select d, what
