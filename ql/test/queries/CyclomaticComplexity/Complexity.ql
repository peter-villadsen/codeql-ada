/** `getCyclomaticComplexity()` of every subprogram of the shipped query's test sources. */

import ada

from Subprogram s
where s.fromSource()
select s, s.getName(), s.getMetrics().getCyclomaticComplexity()
