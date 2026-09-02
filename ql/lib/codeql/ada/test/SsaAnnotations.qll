/**
 * The canonical rendering of SSA definitions and def-use/phi-input edges used
 * by the inline-expectation annotations in the SSA conformance tests (Task
 * 9.2.4).
 *
 * Lives in the library pack, alongside `CfgAnnotations.qll`, for the same
 * reason: the conformance check (`ql/test/library/Ssa/SsaConformance.qll`)
 * and the debug query that prints annotations for transcription
 * (`ql/debug/SsaAnnotations.ql`) share one definition and cannot drift apart.
 *
 * Two kinds of edge are checked, both surfaced directly by the shared
 * `codeql/ssa` framework's own `Make` output (`SsaImpl.qll`), not
 * reimplemented here:
 *
 * - **def-use**: `SsaImpl::Make::ssaDefReachesRead(v, def, bb, i)` -- a
 *   definition `def` of `v` reaches a read at CFG position `(bb, i)`. Every
 *   `Definition` that survives dead-store elision reaches at least one read
 *   by construction (that is what "survives" means), so checking this
 *   relation exhaustively also exhaustively checks which definitions exist.
 * - **phi input**: `phiHasInputFromBlock(phi, inp, bb)` -- `inp` is the
 *   definition reaching the end of `bb`, one of `phi`'s predecessor blocks.
 *
 * See `docs/ssa-design.md` for the annotation format and per-construct
 * expectations.
 */

import codeql.ada.controlflow.Cfg
private import codeql.ada.test.CfgAnnotations
private import codeql.ada.dataflow.internal.SsaImpl

/**
 * Gets the annotation key for definition `d`: `def(<var>)@<line>:<col>` for
 * an ordinary write, `phi(<var>)@<line>:<col>` for a phi node, at `d`'s own
 * location.
 */
string defKey(SsaImpl::Definition d) {
  exists(SsaSourceVariable v, int l, int c |
    d.definesAt(v, _, _) and
    d.getLocation().hasLocationInfo(_, l, c, _, _) and
    (
      d instanceof SsaImpl::PhiNode and result = "phi(" + v.toString() + ")@" + l + ":" + c
      or
      not d instanceof SsaImpl::PhiNode and result = "def(" + v.toString() + ")@" + l + ":" + c
    )
  )
}

/** Gets the annotation value for a def-use edge: `def reads use`. */
string readsKey(SsaImpl::Definition def, CfgNode use) {
  result = defKey(def) + "|reads|" + nodeKey(use)
}

/** Gets the annotation value for a phi-input edge: `phi from inp`. */
string phiInputKey(SsaImpl::PhiNode phi, SsaImpl::Definition inp) {
  result = defKey(phi) + "|from|" + defKey(inp)
}
