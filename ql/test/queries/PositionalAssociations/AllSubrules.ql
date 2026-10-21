/**
 * Every subrule of `codeql.ada.adacontrol.PositionalAssociations`, for the shipped
 * query's test sources: each kind of association with its `all`, `all_positional`,
 * `same_type` and `declared` counts.
 */

import ada
import codeql.ada.adacontrol.PositionalAssociations

from AdaNode site, AdaNode list, string kind, string what
where
  PositionalAssociations::associations(site, list, kind) and
  site.fromSource() and
  exists(PositionalAssociations::positionalCount(list)) and
  what =
    kind + ": all " + PositionalAssociations::allCount(list) + ", all_positional " +
      PositionalAssociations::positionalCount(list) + ", same_type " +
      concat(PositionalAssociations::sameTypeCount(list).toString()) + ", declared " +
      concat(PositionalAssociations::declaredCount(site).toString())
select site, what
