/**
 * @name Declaration could have a smaller scope
 * @description A declaration should be as local as it can be: when every reference to
 *              it is in one inner scope, it can be declared there, and when a package
 *              spec declares it but only the package body uses it, it belongs in the
 *              body. AdaControl rule `Reduceable_Scope`, all categories (`variable`,
 *              `constant`, `subprogram`, `type`, `package`, `exception`, `generic`):
 *              declarations that could move to an inner scope (a subprogram, entry,
 *              task or package body, or a block), to the package body, and local
 *              declarations that are not used. Initialized objects and constants,
 *              task objects, entities whose `'Access` or `'Address` is taken and
 *              primitive operations of tagged types do not move to an inner scope.
 *              Left out: `use`, `use_type` and `use_all_type` (see
 *              `ada/unnecessary-use-clause`, `movable`). `no_blocks` and `to_body` are
 *              in `codeql.ada.adacontrol.ReduceableScope` (`docs/adacontrol.md`).
 * @id ada/reduceable-scope
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.ReduceableScope
import codeql.ada.adacontrol.Generated

/** Gets a description of scope `s`. */
string scopeName(AdaNode s) {
  result = "subprogram " + s.(Raw::SubpBody).getSubpSpec().getSubpName().getName().getText()
  or
  result = "entry " + s.(Raw::EntryBody).getEntryName().getName().getText()
  or
  result = "task body " + s.(Raw::TaskBody).getName().getName().getText()
  or
  result = "package body " + s.(Raw::PackageBody).getPackageName().getName().getText()
  or
  s instanceof Raw::BlockStmt and result = "block"
}

from AdaNode e, string msg, AdaNode target, string label
where
  not isBinderGenerated(e) and
  exists(string cat, string name |
    cat = ReduceableScope::category(e) and
    name = any(string n | n = e.(Raw::BasicDecl).getADefiningName().getName().getText() or n = e.(Raw::DefiningName).getName().getText())
  |
    ReduceableScope::innerScope(e, target, true) and
    msg = "The " + cat + " " + name + " could be declared in $@." and
    label = scopeName(target)
    or
    exists(Raw::BasePackageDecl p | ReduceableScope::toBody(e, p) |
      msg = "The " + cat + " " + name + " is used only in the body of package $@, where it could be declared." and
      target = p and
      label = p.getPackageName().getName().getText()
    )
    or
    ReduceableScope::unused(e) and
    msg = "The " + cat + " $@ is not used." and
    target = e and
    label = name
  )
select e, msg, target, label
