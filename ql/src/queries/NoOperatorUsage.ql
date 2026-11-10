/**
 * @name Integer type without arithmetic
 * @description An integer type on which no arithmetic operator is ever used is a set of
 *              values rather than a quantity: an enumeration type says so and lets the
 *              compiler check `case` statements; a modular type used only with `and`,
 *              `or` and `xor` is a set of flags, clearer as an array of Booleans.
 *              AdaControl rule `No_Operator_Usage`, with its default: every integer
 *              type, signed or modular, of the source, outside the files the GNAT
 *              binder generates. The `relational`, `logical` and
 *              `indexing` filters are in `codeql.ada.adacontrol.NoOperatorUsage`
 *              (`docs/adacontrol.md`).
 * @id ada/no-operator-usage
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.NoOperatorUsage
import codeql.ada.adacontrol.Generated

from Type t, string category, string what
where
  NoOperatorUsage::noArithmetic(t, category) and
  not isBinderGenerated(t) and
  if category = "mod" and NoOperatorUsage::usesLogical(t)
  then what = " but logical ones: could it be an array of Booleans?"
  else what = ": could it be an enumeration type?"
select t, "No arithmetic operator is used on integer type " + t.getName() + what
