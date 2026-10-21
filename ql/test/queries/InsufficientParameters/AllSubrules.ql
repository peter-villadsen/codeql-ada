/**
 * `codeql.ada.adacontrol.InsufficientParameters` with `Standard.Boolean` and `Test.Color`
 * as the enumeration types, every count, for the shipped query's test sources.
 */

import ada
import codeql.ada.adacontrol.InsufficientParameters

predicate isListed(Type t) { t.hasQualifiedName(["Standard.Boolean", "Test.Color"]) }

module Insufficient = InsufficientParameters::Make<isListed/1>;

from Call call
where call.fromSource()
select call, Insufficient::insufficientCount(call)
