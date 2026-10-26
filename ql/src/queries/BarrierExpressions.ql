/**
 * @name Complex entry barrier
 * @description An entry barrier is evaluated by the protected object's lock on every
 *              protected action that could change it; one that calls functions, reads
 *              variables outside the object, indexes, dereferences or allocates can raise
 *              an exception or block there, and makes the object's timing hard to bound.
 *              AdaControl rule `Barrier_Expressions`, allowing what Ada 2022's
 *              `Pure_Barriers` restriction (the Jorvik profile) allows: components of the
 *              protected object, literals, named numbers, `'Count` and other attributes
 *              that are values, comparisons and logical operators. See
 *              `codeql.ada.adacontrol.BarrierExpressions` (`docs/adacontrol.md`).
 * @id ada/barrier-expressions
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags reliability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.BarrierExpressions

/** Gets construct `n` of keyword `kw`, in words. */
string describe(Expr n, string kw) {
  kw = "allocation" and result = "an allocator"
  or
  kw = "any_variable" and result = n.(Name).getText() + ", declared outside the protected object"
  or
  kw = "arithmetic_operator" and result = "an arithmetic operator"
  or
  kw = "array_aggregate" and result = "an array aggregate"
  or
  kw = "conversion" and result = "a conversion or qualification"
  or
  kw = "dereference" and result = "a dereference"
  or
  kw = "indexing" and result = "an indexing or slice"
  or
  kw = "function_attribute" and
  result = "the attribute '" + n.(AttributeRef).getAttribute().getValue()
  or
  kw = "local_function" and result = "a call to a protected function"
  or
  kw = "call" and result = "a function call"
  or
  kw = "record_aggregate" and result = "a record aggregate"
}

from Expr n, EntryBody b, string kw
where
  BarrierExpressions::construct(n, b, kw) and
  not kw = ["any_component", "comparison_operator", "logical_operator", "value_attribute"] and
  n.fromSource()
select n,
  "The barrier of entry " + b.getEntryName().getName().getText() + " uses " + describe(n, kw) +
    "."
