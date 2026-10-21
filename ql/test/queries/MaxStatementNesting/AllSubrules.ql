/** `MaxStatementNesting::depth` of every compound statement of the shipped query's test sources, by kind. */

import ada
import codeql.ada.adacontrol.MaxStatementNesting

from Stmt s, string kind
where s.fromSource() and exists(MaxStatementNesting::depth(s, kind))
select s, kind, MaxStatementNesting::depth(s, kind)
