/**
 * Every subrule of `codeql.ada.adacontrol.Assignments`, for the shipped query's test
 * sources.
 */

import ada
import codeql.ada.adacontrol.Assignments

from AdaNode site, string what
where
  site.fromSource() and
  (
    exists(AssignStmt first |
      Assignments::repeated(first, site) and
      what =
        "repeated " + first.getLocation().getStartLine() +
          any(string r |
            if Assignments::readBetween(first, site) then r = " (read between)" else r = ""
          )
    )
    or
    exists(DefiningName object, Type t, int given, int total |
      Assignments::groupable(site, object, t, given, total) and
      what =
        "groupable " + object.getName().getText() + " " + given + "/" + total +
          any(string r | if Assignments::groupReads(site, object) then r = " (read)" else r = "")
    )
    or
    exists(int tf, int vf | Assignments::sliding(site, tf, vf) |
      what = "sliding " + vf + " into " + tf
    )
    or
    exists(Name value, boolean controlled |
      Assignments::accessDuplication(site, value, controlled) and
      what = "access_duplication " + value.toString() + " controlled=" + controlled
    )
    or
    exists(Type t, boolean component |
      Assignments::assignsType(site, t, component) and
      t.fromSource() and
      what = "type " + t.getName() + " component=" + component
    )
    or
    exists(Name sub, boolean trivial |
      Assignments::possibleTargetName(site, sub, trivial) and
      what =
        "possible_target_name " + sub.toString() + " trivial=" + trivial + " components=" +
          Assignments::nameComponents(sub)
    )
  )
select site, what
