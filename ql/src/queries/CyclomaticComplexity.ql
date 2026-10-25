/**
 * @name Subprogram too complex
 * @description A subprogram whose McCabe cyclomatic complexity is above 10 has more
 *              independent paths than a reader can follow or a test suite can cover
 *              comfortably; split it. The complexity is one more than the number of
 *              decisions in the body (`if`, `elsif`, loops, `exit when`, `and then`,
 *              `or else`, quantified expressions, each `case` or `select` alternative
 *              after the first, each exception handler), not counting nested
 *              subprograms. The limit of 10 is set with the data extension
 *              `cyclomaticComplexityThreshold` (`docs/user-guide.md`, "Configuring
 *              queries").
 * @id ada/cyclomatic-complexity
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability
 */

import ada
import codeql.ada.metrics.Limits

from Subprogram s, int complexity, int limit
where
  s.fromSource() and
  complexity = s.getMetrics().getCyclomaticComplexity() and
  limit = Limits::cyclomaticComplexity() and
  complexity > limit
select s.getBody(),
  "This subprogram has cyclomatic complexity " + complexity + ", above the limit of " + limit +
    "."
