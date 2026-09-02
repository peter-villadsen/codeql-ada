/**
 * Debugging aid: dumps every reference resolved to a `SsaSourceVariable`
 * (Task 9.2.2). Not a test — see `PrintSsa.ql`'s header for why.
 */

import ada
private import codeql.ada.dataflow.internal.SsaImpl

from Name n, SsaSourceVariable v
where v = getSourceVariable(n)
select n, n.getLocation().getStartLine() as line, v.toString() as variable
  order by line
