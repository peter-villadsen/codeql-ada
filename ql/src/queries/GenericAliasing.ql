/**
 * @name Same actual for two generic formals
 * @description An instantiation that gives the same variable for two `in out` formal
 *              objects lets the generic update one object through two names, which
 *              its code assumes are distinct. AdaControl rule `Generic_Aliasing`,
 *              `certain variable`: the same variable, or a part of it at static
 *              indices. The `possible` and `unlikely` conditions, and the same type,
 *              subprogram or package for two formals (which maps from a type to the
 *              same type do by design), are in `codeql.ada.adacontrol.GenericAliasing`
 *              (`docs/adacontrol.md`).
 * @id ada/generic-aliasing
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.GenericAliasing
import codeql.ada.adacontrol.Instantiations

from Raw::GenericInstantiation inst, int i, int j, string kind, Raw::Expr first
where
  inst.fromSource() and
  GenericAliasing::aliasing(inst, i, j, kind, "certain") and
  kind = "variable" and
  first = Instantiations::actual(inst, i)
select Instantiations::actual(inst, j),
  "The same " + kind + " is given for formal " + GenericAliasing::formal(inst, j).getName().getText() +
    " as for formal " + GenericAliasing::formal(inst, i).getName().getText() + " ($@).", first,
  first.toString()
