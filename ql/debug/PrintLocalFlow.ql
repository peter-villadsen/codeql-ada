/**
 * Debugging aid: dumps every local data-flow step (Task 9.3).
 *
 * Run it over a fixture and read the steps against the source. Deliberately not a
 * query and not polished: an intraprocedural flow demo is not a deliverable of
 * Phase 9 (phase9-plan.md). The regression test is `ql/test/library/LocalFlow`.
 */

import ada
import codeql.ada.dataflow.internal.LocalFlow

from Node a, Node b
where localFlowStep(a, b)
select a, b
