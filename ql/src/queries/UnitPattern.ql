/**
 * @name Several tagged types in one package
 * @description A package that declares more than one tagged type mixes classes; a coding
 *              standard of one class per package wants each in its own package.
 *              AdaControl rule `Unit_Pattern`, subrule `single_tagged_type`.
 *              `tagged_type_hierarchy`, `context_clauses_order` and `declarations_order`
 *              are in `codeql.ada.adacontrol.UnitPattern` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/unit-pattern
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.UnitPattern

from BasePackageDecl p, Type t, Type first
where
  UnitPattern::secondTaggedType(p, t, first) and
  not exists(Type earlier | UnitPattern::secondTaggedType(p, first, earlier)) and
  t.fromSource()
select t, "Package declares $@ already; " + t.getName() + " is a second tagged type.", first,
  first.getName()
