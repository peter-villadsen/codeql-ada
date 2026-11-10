/**
 * The properties `codeql.ada.adacontrol.NoOperatorUsage` gives each integer type of
 * the shipped query's test sources.
 */

import ada
import codeql.ada.adacontrol.NoOperatorUsage

from Type t, string category, string what
where
  NoOperatorUsage::isIntegerType(t, category) and
  (
    NoOperatorUsage::usesArithmetic(t) and what = "arithmetic"
    or
    NoOperatorUsage::usesRelational(t) and what = "relational"
    or
    NoOperatorUsage::usesLogical(t) and what = "logical"
    or
    NoOperatorUsage::isIndex(t) and what = "indexing"
    or
    not NoOperatorUsage::usesArithmetic(t) and what = "no arithmetic"
  )
select t, category, what
