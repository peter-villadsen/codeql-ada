/**
 * Debugging aid: the shared data-flow library's consistency checks over the Ada
 * `InputSig` (Task 9.4). Run it over any database; every result is a violation.
 * The regression test on the fixture is `ql/test/library/DataFlow/Consistency.ql`.
 */

import codeql.ada.dataflow.internal.DataFlowConsistency
