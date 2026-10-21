/**
 * `codeql.ada.adacontrol.TypeInitialValues` on the shipped query's test sources: each
 * checked type's initial constants, and whether it lacks one, with no pattern and with
 * `^C_Init_`.
 */

import ada
import codeql.ada.adacontrol.TypeInitialValues

from Type t, string what
where
  t.fromSource() and
  (
    exists(Variable c | TypeInitialValues::initialConstant(t, c) | what = "constant " + c.getName())
    or
    TypeInitialValues::lacksInitialValue(t, "") and what = "lacks any"
    or
    TypeInitialValues::lacksInitialValue(t, "^C_Init_") and what = "lacks ^C_Init_"
  )
select t, what
