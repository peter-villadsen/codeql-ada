/**
 * Every predicate of `codeql.ada.adacontrol.RecordDeclarations`, for the shipped query's
 * test sources: components by type and category, and the representation conditions.
 */

import ada
import codeql.ada.adacontrol.RecordDeclarations

from Component c, string what
where
  c.fromSource() and
  (
    exists(Type t, boolean exact |
      RecordDeclarations::isOfType(c, t, exact) and what = "type " + t.getName()
    )
    or
    exists(string cat |
      cat = ["()", "range", "array"] and
      RecordDeclarations::isOfCategory(c, cat) and
      what = "category " + cat
    )
    or
    RecordDeclarations::inVariant(c) and what = "in_variant"
    or
    RecordDeclarations::isInitialized(c) and what = "initialized"
    or
    RecordDeclarations::isSized(c) and what = "sized"
    or
    RecordDeclarations::isAligned(c) and what = "aligned"
    or
    RecordDeclarations::isPacked(c) and what = "packed"
  )
select c, what
