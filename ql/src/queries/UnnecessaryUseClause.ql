/**
 * @name Unnecessary use clause
 * @description A `use` clause makes names visible without their package; one that
 *              nothing needs only hides where names come from. AdaControl rule
 *              `Unnecessary_Use_Clause`, all subrules: `unused` (nothing in the scope
 *              uses the package, or the type's operators), `qualified` (every use is
 *              qualified anyway), `operator` (only operators are used directly: `use
 *              type` would do), `primitive` (only primitive operations and literals:
 *              `use all type` would do), `nested` (already visible: in the scope of
 *              another clause for it, or inside the package), `movable` (a clause of a
 *              package spec used only in the body). Left out: `Max_Replacements`. See
 *              `codeql.ada.adacontrol.UnnecessaryUseClause` (`docs/adacontrol.md`).
 * @id ada/unnecessary-use-clause
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.UnnecessaryUseClause
import codeql.ada.adacontrol.Generated

/** Gets the message for `subrule`, about the clause's name `n`. */
bindingset[subrule, n]
string message(string subrule, string n) {
  subrule = "unused" and result = "Unused: nothing in its scope uses " + n + "."
  or
  subrule = "qualified" and result = "Qualified: every use of " + n + " is qualified."
  or
  subrule = "operator" and
  result = "Operator: only operators of " + n + " are used directly; use type would do."
  or
  subrule = "primitive" and
  result = "Primitive: only primitive operations of types of " + n + " are used directly; use all type would do."
  or
  subrule = "nested" and result = "Nested: " + n + " is already visible here."
  or
  subrule = "movable" and result = "Movable: " + n + " is used only in the body, where the clause could be."
}

from Raw::UseClause u, Raw::Name name, string subrule
where
  UnnecessaryUseClause::unnecessary(u, name, subrule) and
  not isBinderGenerated(u)
select name, message(subrule, name.getText())
