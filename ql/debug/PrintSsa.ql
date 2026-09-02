/**
 * Debugging aid: dumps SSA definitions and their reads (Phase 9.2).
 *
 * Not a test — every `.ql` under `ql/test` is treated as one needing an
 * `.expected` file. This lives here for the same reason `PrintCfg.ql` does:
 * dump the actual output for a fixture, compare against the design doc, and
 * transcribe into inline expectations. See docs/phase9.2-plan.md Task 9.2.4.
 */

import ada
private import codeql.ada.dataflow.internal.SsaImpl

from SsaImpl::Definition d
select d, d.getSourceVariable().toString()
