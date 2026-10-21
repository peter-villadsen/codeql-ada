/**
 * @name Insufficient parameters
 * @description A call with two or more actuals given by position that are only numeric
 *              or Boolean literals (`Draw (3, 4, True)`) does not tell the reader what
 *              they are for; name them. AdaControl rule `Insufficient_Parameters` with
 *              1 and `Standard.Boolean`. Other limits and enumeration types are in
 *              `codeql.ada.adacontrol.InsufficientParameters` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/insufficient-parameters
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.InsufficientParameters

predicate isBoolean(Type t) { t.hasQualifiedName("Standard.Boolean") }

module Insufficient = InsufficientParameters::Make<isBoolean/1>;

from Call call, int n
where n = Insufficient::insufficientCount(call) and n > 1 and call.fromSource()
select call,
  "This call has " + n + " actuals given by position that are only literals: name them."
