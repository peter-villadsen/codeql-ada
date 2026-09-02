/**
 * @name Print SSA expectation annotations
 * @description For each line of each file, prints the complete inline
 *              expectation comment that the SSA conformance test expects on
 *              that line, ready to paste into the `.adb`.
 * @kind table
 * @id ada/debug/ssa-annotations
 *
 * Transcribe the output only *after* checking the graph against the rule in
 * `docs/ssa-design.md`. This query reports what the implementation does,
 * which is the thing under test -- pasting it blindly turns a conformance
 * test into a tautology.
 */

import codeql.ada.controlflow.Cfg
import codeql.ada.controlflow.BasicBlocks
import codeql.ada.test.CfgAnnotations
import codeql.ada.test.SsaAnnotations
import codeql.ada.dataflow.internal.SsaImpl

private string readsAnnotation(SsaImpl::Definition def, string file, int line) {
  exists(BasicBlock bb, int i, CfgNode use, string path |
    SsaImpl::ssaDefReachesRead(_, def, bb, i) and
    use = bb.getNode(i) and
    def.getLocation().hasLocationInfo(path, _, _, line, _) and
    file = path.regexpReplaceAll(".*[/\\\\]", "") and
    result = "ssa=" + readsKey(def, use)
  )
}

private string fromAnnotation(SsaImpl::PhiNode phi, string file, int line) {
  exists(SsaImpl::Definition inp, string path |
    SsaImpl::phiHasInputFromBlock(phi, inp, _) and
    inp.getLocation().hasLocationInfo(path, _, _, line, _) and
    file = path.regexpReplaceAll(".*[/\\\\]", "") and
    result = "ssa=" + phiInputKey(phi, inp)
  )
}

from string file, int line, string annotation
where
  annotation =
    "-- $ " +
      strictconcat(string one |
        one = readsAnnotation(_, file, line) or one = fromAnnotation(_, file, line)
      |
        one, " " order by one
      )
select file, line, annotation order by file, line
