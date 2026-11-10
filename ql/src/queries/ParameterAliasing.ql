/**
 * @name Same variable for two parameters
 * @description A call that passes the same variable, or overlapping parts of one, for two
 *              `out` or `in out` parameters lets the callee update one object through
 *              two names; which value is left depends on how the parameters are
 *              passed. AdaControl rule `Parameter_Aliasing`, `certain`: the same
 *              variable, or a part of it at static indices. The `possible` and
 *              `unlikely` conditions and `with_in` are in
 *              `codeql.ada.adacontrol.ParameterAliasing` (`docs/adacontrol.md`).
 * @id ada/parameter-aliasing
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.ParameterAliasing

from Call c, Parameter p, Parameter q, Raw::Expr first
where
  c.fromSource() and
  ParameterAliasing::aliasing(c, p, q, "certain", false) and
  first = c.getArgumentFor(p)
select c.getArgumentFor(q),
  "The same variable is passed for parameter " + q.getName() + " as for parameter " + p.getName() +
    " ($@) of " + c.getTarget().getName() + ".", first, first.toString()
