/**
 * @name Questionable assignment
 * @description An assignment that a later one in the same group overwrites before
 *              anything reads it is dead; components of a record assigned one by one,
 *              all of them, read better and are checked better as one aggregate
 *              assignment; and an array assigned from one with a different lower bound
 *              slides, so that `A (I)` and `B (I)` are no longer the same element.
 *              AdaControl rule `Assignments`, subrules `repeated` (when the target is
 *              not read in between), `groupable` (every component of a record without
 *              discriminants, at least two) and `sliding` (whole variables with static
 *              bounds, and string literals). `type`, `access_duplication` and
 *              `possible_target_name` are in `codeql.ada.adacontrol.Assignments` for a
 *              query of your own (`docs/adacontrol.md`).
 * @id ada/assignments
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.Assignments

from AdaNode site, string msg, AdaNode other, string otherText
where
  site.fromSource() and
  (
    exists(AssignStmt first |
      Assignments::repeated(first, site) and
      not Assignments::readBetween(first, site) and
      msg = "This assignment overwrites $@ before anything reads it." and
      other = first and
      otherText = "an earlier assignment"
    )
    or
    exists(DefiningName object, Type t, int given |
      Assignments::groupable(site, object, t, given, given) and
      given >= 2 and
      not Assignments::groupReads(site, object) and
      msg =
        "These assignments set all " + given + " components of $@ one by one: assign an aggregate." and
      other = object and
      otherText = object.getName().getText()
    )
    or
    exists(int targetFirst, int valueFirst |
      Assignments::sliding(site, targetFirst, valueFirst) and
      msg =
        "This assignment slides: the value's indices start at " + valueFirst +
          ", the target's ($@) at " + targetFirst + "." and
      other = site.(AssignStmt).getDest() and
      otherText = site.(AssignStmt).getDest().getText()
    )
  )
select site, msg, other, otherText
