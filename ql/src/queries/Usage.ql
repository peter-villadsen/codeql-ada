/**
 * @name Entity usage
 * @description How an entity is used tells what it should be: a variable that is
 *              initialized and read but never written could be a constant, an `in out`
 *              parameter that is never written could be `in`, a subprogram of a
 *              package's visible part that is never called could be removed. AdaControl
 *              rule `Usage`, for the classes and conditions named with the data
 *              extension `usage` (class, comma-separated conditions such as
 *              `written, not read`): the entities of the class that satisfy every
 *              condition. With no row, nothing is reported. Left out: the place
 *              `from_task_guard`. See `codeql.ada.adacontrol.Usage` (`docs/adacontrol.md`).
 * @id ada/usage
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Usage
import codeql.ada.adacontrol.Settings

/** Gets the class of `e` as a phrase: `In_Parameter` becomes `In parameter`. */
string classPhrase(AdaNode e) {
  exists(string c | c = Usage::entityClass(e).replaceAll("_", " ") |
    result = c.charAt(0).toUpperCase() + c.suffix(1)
  )
}

from AdaNode e, string msg
where
  exists(string cls, string conditions |
    usage(cls, conditions) and
    Usage::inClass(e, cls) and
    forall(string item | item = conditions.splitAt(",").trim() and item != "" |
      Usage::satisfies(e, item)
    )
  ) and
  msg =
    classPhrase(e) + " " + Usage::entityName(e) + ": " + Usage::description(e) +
      any(string extra |
        if
          Usage::entityClass(e) = "variable" and
          Usage::holds(e, "initialized") and
          Usage::holds(e, "read") and
          not Usage::holds(e, "written")
        then extra = "; could be declared constant."
        else extra = "."
      )
select e, msg
