/**
 * @name Declaration hides an outer one
 * @description A declaration with the name of a declaration of the same family (an
 *              object, a type, a package, ...) in an enclosing region hides it: inside,
 *              the name means the inner one, and the reader may mean the outer one.
 *              AdaControl rule `Local_Hiding`, `not_different_families strict`. The
 *              subrule `overloading`, and the exceptions `not_operator`,
 *              `not_enumeration` and `not_identical_renaming`, are in
 *              `codeql.ada.adacontrol.LocalHiding` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/local-hiding
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.LocalHiding

from BasicDecl inner, BasicDecl outer
where
  LocalHiding::hides(inner, outer) and
  LocalHiding::family(inner) = LocalHiding::family(outer) and
  inner.fromSource()
select inner, inner.getAName() + " hides $@ declared in an enclosing region.", outer,
  outer.getAName()
