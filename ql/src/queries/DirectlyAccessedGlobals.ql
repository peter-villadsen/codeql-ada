/**
 * @name Global variable accessed directly
 * @description A variable of a package body that several subprograms read and write
 *              has no single place that guards it: with tasks, two of them can race on
 *              it. Each such variable should be read by one dedicated subprogram (or
 *              protected object, or task) and written by one, and only those should
 *              name it. AdaControl rule `Directly_Accessed_Globals`, with every kind of
 *              accessor allowed: plain subprograms, single protected objects and the
 *              `accept` statements of single tasks, declared directly in the package
 *              body. `codeql.ada.adacontrol.DirectlyAccessedGlobals` gives each
 *              accessor's kind, to allow fewer (`docs/adacontrol.md`). Files the GNAT
 *              binder generates (`b__*.adb`, `b~*.adb`), whose elaboration flags are
 *              globals by design, are left out.
 * @id ada/directly-accessed-globals
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.DirectlyAccessedGlobals

/** Gets why an access outside a dedicated callable is reported, in words. */
string describe(string reason) {
  reason = "outside" and result = "outside any subprogram"
  or
  reason = "nested" and result = "in a callable not declared directly in the package body"
  or
  reason = "generic" and result = "in a generic subprogram"
  or
  reason = "type" and result = "in an operation of a protected or task type"
  or
  reason = "task body" and result = "in a task body, outside an accept statement"
}

/** Gets the accessors of `v` with access `mode`, by name. */
bindingset[mode]
string accessors(Variable v, string mode) {
  result =
    concat(AdaNode a, string name |
      DirectlyAccessedGlobals::accessedBy(v, a, mode) and
      name = DirectlyAccessedGlobals::accessorName(a)
    |
      name, ", " order by name
    )
}

from AdaNode site, string msg, Variable v
where
  site.fromSource() and
  not exists(string path |
    site.getLocation().hasLocationInfo(path, _, _, _, _) and path.regexpMatch(".*/b(__|~)[^/]*")
  ) and
  (
    exists(string reason |
      DirectlyAccessedGlobals::undedicatedAccess(v, site, reason) and
      msg = "Global variable $@ is accessed " + describe(reason) + "."
    )
    or
    DirectlyAccessedGlobals::tooManyAccessors(v) and
    site = v and
    msg =
      "Global variable $@ is " +
        concat(string mode, string verb |
          (mode = "read" and verb = "read by " or mode = "write" and verb = "written by ") and
          DirectlyAccessedGlobals::accessedBy(v, _, mode)
        |
          verb + accessors(v, mode), " and " order by mode
        ) + ": give it one reader and one writer."
  )
select site, msg, v, v.getName()
