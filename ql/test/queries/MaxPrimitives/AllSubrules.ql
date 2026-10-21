/** `MaxPrimitives::visibleCount` and `totalCount` of every type of the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.MaxPrimitives

from Type t
where t.fromSource()
select t, MaxPrimitives::visibleCount(t), MaxPrimitives::totalCount(t)
