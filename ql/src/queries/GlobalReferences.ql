/**
 * @name Global variable shared between tasks
 * @description A variable that several tasks or protected objects read and write,
 *              directly or through the subprograms they call, is a data race unless
 *              something else serializes them. AdaControl rule `Global_References`,
 *              subrule `multiple_non_atomic`, with the roots `task` and `protected`:
 *              a variable accessed from more than one task or protected body, or from
 *              the body of a task or protected type (of which there may be several
 *              objects), unless it is atomic and written by one root at most. The
 *              query also requires a root to write it: a variable the roots only read
 *              is set before they start. The other subrules, and subprograms as roots,
 *              are in `codeql.ada.adacontrol.GlobalReferences` (`docs/adacontrol.md`).
 *              Calls through access-to-subprogram values and dispatching calls are
 *              not followed.
 * @id ada/global-references
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @tags reliability concurrency adacontrol
 */

import ada
import codeql.ada.adacontrol.GlobalReferences
import codeql.ada.adacontrol.Generated

/** Holds if `r` is a task or protected body outside the files the GNAT binder generates. */
predicate isConcurrentRoot(Raw::AdaNode r) {
  GlobalReferences::rootKind(r) = ["task", "protected"] and
  r.fromSource() and
  not isBinderGenerated(r)
}

module Concurrent = GlobalReferencesMultiple<isConcurrentRoot/1>;

/** Gets root `r` described: its kind and name, and `type` for a task or protected type. */
string describe(Raw::AdaNode r) {
  result =
    GlobalReferences::rootKind(r) +
      any(string t | if GlobalReferences::isTypeRoot(r) then t = " type " else t = " ") +
      GlobalReferences::rootName(r)
}

/** Gets root `r` described with what it does to `v`: `task A (read, written)`. */
string access(Raw::AdaNode r, Variable v) {
  r = Concurrent::accessor(v, _) and
  result =
    describe(r) + " (" +
      concat(string mode, string word |
        r = Concurrent::accessor(v, mode) and
        (mode = "read" and word = "read" or mode = "write" and word = "written")
      |
        word, ", " order by word
      ) + ")"
}

from Variable v
where
  v.fromSource() and
  Concurrent::multipleNonAtomic(v) and
  exists(Concurrent::accessor(v, "write"))
select v,
  "Global variable " + v.getName() + " is accessed by " +
    concat(Raw::AdaNode r, string a | a = access(r, v) | a, ", " order by a) + "."
