/**
 * @name Complex subprogram
 * @description A subprogram whose cyclomatic complexity is above a threshold.
 * @kind problem
 * @id my-app/complex-subprogram
 * @problem.severity recommendation
 */

import ada

from Subprogram s, int complexity
where
  s.fromSource() and
  complexity = s.getMetrics().getCyclomaticComplexity() and
  complexity > 5
select s, "This subprogram has cyclomatic complexity " + complexity + "."
