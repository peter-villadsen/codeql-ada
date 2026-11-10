/**
 * The subrules of `codeql.ada.adacontrol.GlobalReferences` for the shipped query's
 * test sources: what each root reads and writes (`reference`), where (`referenceSite`),
 * and `multiple` and `multiple_non_atomic` for every root.
 */

import ada
import codeql.ada.adacontrol.GlobalReferences

predicate anyRoot(Raw::AdaNode r) { exists(GlobalReferences::rootKind(r)) and r.fromSource() }

module All = GlobalReferencesMultiple<anyRoot/1>;

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(Raw::AdaNode r, string mode | GlobalReferences::reference(r, n, mode) |
      what =
        GlobalReferences::rootKind(r) + " " + GlobalReferences::rootName(r) + " " + mode +
          "s it"
    )
    or
    exists(Raw::AdaNode r, Variable v, string mode |
      GlobalReferences::referenceSite(r, v, n, mode)
    |
      what = mode + " of " + v.getName() + " for " + GlobalReferences::rootName(r)
    )
    or
    All::multiple(n) and what = "multiple"
    or
    All::multipleNonAtomic(n) and what = "multiple_non_atomic"
    or
    GlobalReferences::isTypeRoot(n) and what = "type root"
  )
select n, what
