/**
 * The SSA conformance test: checks that the SSA graph built for each
 * `test.adb` in this directory tree matches, edge for edge, the expectations
 * annotated in that file (Task 9.2.4, mirroring the CFG conformance tests of
 * Phase 7.7 -- see `ql/test/library/Cfg/CfgConformance.qll`).
 *
 * A test query is a one-liner:
 *
 * ```ql
 * import library.Ssa.SsaConformance
 * ```
 *
 * paired with an **empty** `test.expected`. Every def-use and phi-input edge
 * must be annotated and every annotation must correspond to an edge, so the
 * check is exhaustive in both directions.
 *
 * ## Annotation format
 *
 * ```
 * -- $ ssa=<def>|reads|<use>
 * -- $ ssa=<phi>|from|<inp>
 * ```
 *
 * where `<def>`/`<phi>`/`<inp>` are rendered by `defKey` as
 * `def(<var>)@<line>:<col>` (an ordinary write) or `phi(<var>)@<line>:<col>`
 * (a phi node), and `<use>` is rendered by `nodeKey` (`CfgAnnotations.qll`,
 * reused unchanged) as `<kind>@<line>:<col>`.
 *
 * Every `Definition` that survives dead-store elision reaches at least one
 * read by construction, so the `reads` edges alone exhaustively pin down
 * which definitions exist, not only where they are read.
 *
 * The annotation for a `reads` edge goes on the line where the
 * **definition** ends, matching the CFG tests' predecessor-anchoring
 * convention; a `from` edge is anchored the same way, at the *input*
 * definition's own end line -- it is the earlier of the two in program
 * order, the same role `pred` plays for a CFG edge.
 *
 * `ql/debug/SsaAnnotations.ql` prints the complete annotation comment for
 * every line of a file, so annotations are transcribed, not typed. Transcribe
 * only after checking the graph against the rule in `docs/ssa-design.md`.
 */

import codeql.ada.controlflow.ControlFlowGraph
private import codeql.ada.test.SsaAnnotations
private import codeql.ada.test.InlineExpectationsTest
private import codeql.ada.dataflow.internal.SsaImpl

private module SsaEdgeTest implements TestSig {
  string getARelevantTag() { result = "ssa" }

  predicate hasActualResult(Location location, string element, string tag, string value) {
    exists(SsaImpl::Definition def, BasicBlock bb, int i, ControlFlowNode use |
      SsaImpl::ssaDefReachesRead(_, def, bb, i) and
      use = bb.getNode(i) and
      location = def.getLocation() and
      element = def.toString() and
      tag = "ssa" and
      value = readsKey(def, use)
    )
    or
    exists(SsaImpl::PhiNode phi, SsaImpl::Definition inp |
      SsaImpl::phiHasInputFromBlock(phi, inp, _) and
      location = inp.getLocation() and
      element = inp.toString() and
      tag = "ssa" and
      value = phiInputKey(phi, inp)
    )
  }
}

import MakeTest<SsaEdgeTest>
