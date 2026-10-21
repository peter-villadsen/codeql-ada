/**
 * @name Positional actuals of the same type
 * @description A call with more than 3 actuals of the same type given by position can
 *              have two of them swapped without any error from the compiler; name them.
 *              AdaControl rule `Positional_Associations` with `same_type, 3, call`. The
 *              subrules `all`, `all_positional` and `declared`, and the other kinds of
 *              association (aggregates, discriminants, pragmas, instantiations,
 *              enumeration representations), are in
 *              `codeql.ada.adacontrol.PositionalAssociations` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/positional-associations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.PositionalAssociations

from AdaNode site, AdaNode list, int n
where
  PositionalAssociations::associations(site, list, "call") and
  n = PositionalAssociations::sameTypeCount(list) and
  n > 3 and
  site.fromSource()
select site, "This call gives " + n + " actuals of the same type by position: name them."
