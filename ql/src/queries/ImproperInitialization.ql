/**
 * @name Variable or out parameter used before it is assigned
 * @description A local variable read before it is assigned has no defined value, and a
 *              subprogram that returns without assigning an `out` parameter passes
 *              back garbage. AdaControl rule `Improper_Initialization`, subrules
 *              `variable` and `out_parameter`, on the statements before the first
 *              non-trivial one (loop, block, ...): a read of a target before it is
 *              assigned, a `return` before an `out` parameter is assigned, and an `out`
 *              parameter never assigned in a body of trivial statements. Assigning a
 *              component or an element counts as assigning (AdaControl's rule counts
 *              only whole assignments). Targets are checked when their type is known
 *              to have no default value (scalars and arrays of them) and they are not
 *              aliased (`'Access`, `'Address`); AdaControl also leaves out access and
 *              limited types. The design-pattern checks, a target not
 *              assigned before the first non-trivial statement and a redundant initial
 *              value (`initialized_variable`), are in
 *              `codeql.ada.adacontrol.ImproperInitialization` (`docs/adacontrol.md`).
 * @id ada/improper-initialization
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @tags correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.ImproperInitialization

/**
 * Holds if the query checks `target`: not of an access or limited type, as in
 * AdaControl, not aliased, and of a type known to have no default value.
 */
predicate isChecked(Raw::Name target) {
  not ImproperInitialization::isSkipped(target, _) and
  not ImproperInitialization::isAliased(target) and
  ImproperInitialization::hasNoDefault(ImproperInitialization::targetType(target))
}

from AdaNode site, string msg, AdaNode other, string otherText
where
  site.fromSource() and
  (
    exists(Raw::Name target |
      ImproperInitialization::readBeforeAssign(site, target, _, true) and
      isChecked(target) and
      msg = "$@ is read before it is assigned." and
      other = target and
      otherText = ImproperInitialization::targetName(target)
    )
    or
    exists(Parameter p |
      ImproperInitialization::returnBeforeAssign(site, p, _, true) and
      isChecked(p) and
      msg = "This return may leave out parameter $@ unassigned." and
      other = p and
      otherText = p.getName()
    )
    or
    exists(Raw::SubpBody b |
      ImproperInitialization::notSafelyInitialized(site, b, "out_parameter", true) and
      not exists(ImproperInitialization::firstNonTrivial(b)) and
      isChecked(site) and
      msg = "Out parameter " + ImproperInitialization::targetName(site) + " is never assigned in $@." and
      other = b and
      otherText = "its subprogram"
    )
  )
select site, msg, other, otherText
