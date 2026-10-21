/** Every subrule of `codeql.ada.adacontrol.UseClauses`, for the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.UseClauses

from UseClause u, Name n, string subrule
where UseClauses::controlled(u, n, subrule) and u.fromSource()
select n, subrule
