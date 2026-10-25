/**
 * Limits of the metric queries, set through data extensions (`ext/query-settings.model.yml`;
 * `docs/user-guide.md`, "Configuring queries").
 */

/**
 * Holds if `limit` is a limit for `ada/cyclomatic-complexity`: a subprogram whose
 * cyclomatic complexity (`MetricSubprogram.getCyclomaticComplexity()`) is above it is
 * reported. Rows come from data extensions; there are none by default.
 */
extensible predicate cyclomaticComplexityThreshold(int limit);

module Limits {
  /**
   * Gets the cyclomatic complexity limit: the smallest `cyclomaticComplexityThreshold`
   * row, or 10, McCabe's limit, when there is none.
   */
  int cyclomaticComplexity() {
    if cyclomaticComplexityThreshold(_)
    then result = min(int limit | cyclomaticComplexityThreshold(limit))
    else result = 10
  }
}
