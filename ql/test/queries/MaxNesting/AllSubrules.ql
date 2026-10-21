/** `MaxNesting::depth` of every construct of the shipped query's test sources, for each subrule. */

import ada
import codeql.ada.adacontrol.MaxNesting

from AdaNode n, string kind
where n.fromSource() and kind = ["all", "generic", "task"] and exists(MaxNesting::depth(n, kind))
select n, kind, MaxNesting::depth(n, kind)
