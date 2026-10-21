/**
 * Every subrule of `codeql.ada.adacontrol.ParameterDeclarations`, for the shipped
 * query's test sources: the non-zero counts, the callable kinds, `single_out_parameter`.
 */

import ada
import codeql.ada.adacontrol.ParameterDeclarations

from BasicDecl c, string what
where
  c.fromSource() and
  (
    exists(string subrule, int n |
      n = ParameterDeclarations::parameterCount(c, subrule) and n > 0 and what = subrule + " " + n
    )
    or
    what = "kind " + ParameterDeclarations::callableKind(c)
    or
    exists(boolean noInout |
      ParameterDeclarations::singleOutParameter(c, noInout) and
      what = "single_out_parameter (no_inout: " + noInout + ")"
    )
  )
select c, what
