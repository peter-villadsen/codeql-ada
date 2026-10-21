/** Every subrule of `codeql.ada.adacontrol.SimplifiableStatements`, for the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.SimplifiableStatements

from AdaNode s, string subrule
where SimplifiableStatements::simplifiable(s, subrule) and s.fromSource()
select s, subrule
