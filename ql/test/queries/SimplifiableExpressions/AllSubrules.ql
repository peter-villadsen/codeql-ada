/** Every subrule of `codeql.ada.adacontrol.SimplifiableExpressions`, for the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.SimplifiableExpressions

from Expr e, string subrule
where SimplifiableExpressions::simplifiable(e, subrule) and e.fromSource()
select e, subrule
