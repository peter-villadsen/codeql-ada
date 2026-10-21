/** Every reason of `codeql.ada.adacontrol.TerminatingTasks`, for the shipped query's test sources. */

import ada
import codeql.ada.adacontrol.TerminatingTasks

from TaskBody t, string reason
where TerminatingTasks::isTerminating(t, reason) and t.fromSource()
select t, reason
