/**
 * @name Identifier not in Ada case
 * @description An identifier whose words do not each start with an upper-case letter or
 *              a digit (`my_Variable`, `Next_item`) breaks the usual Ada convention
 *              (`My_Variable`, `Next_Item`, `GPR2_Path`). AdaControl rule
 *              `Naming_Convention` with `all, case_sensitive
 *              "^[A-Z0-9][A-Za-z0-9]*(_[A-Z0-9][A-Za-z0-9]*)*$"`. Conventions per kind of
 *              entity (about a hundred kinds), negative patterns and locations are in
 *              `codeql.ada.adacontrol.NamingConvention` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/naming-convention
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.NamingConvention

predicate adaCase(string kind, string pattern, boolean positive, boolean caseSensitive) {
  kind = "all" and
  pattern = "^[A-Z0-9][A-Za-z0-9]*(_[A-Z0-9][A-Za-z0-9]*)*$" and
  positive = true and
  caseSensitive = true
}

module AdaCase = NamingConvention::Convention<adaCase/4>;

from DefiningName dn
where AdaCase::violates(dn, "all", _) and dn.fromSource()
select dn, NamingConvention::identifier(dn) + " is not in Ada case: each word starts with a capital letter."
