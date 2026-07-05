/**
 * Test harness: dumps every edge of the Ada control-flow graph as
 * `predecessor -> [label] -> successor`, with source locations, so CFG
 * construction can be reviewed against `docs/cfg-design.md`. Test-local query
 * (no `.qlref`); paired with the `test_*.adb` files in this directory.
 */

import codeql.ada.controlflow.Cfg

private string pos(CfgNode n) {
  exists(int l, int c | n.getLocation().hasLocationInfo(_, l, c, _, _) |
    result = l + ":" + c
  )
}

private string nodeStr(CfgNode n) { result = n.toString() + " @" + pos(n) }

private string fileOf(CfgNode n) {
  exists(string p | n.getLocation().hasLocationInfo(p, _, _, _, _) |
    result = p.regexpReplaceAll(".*[/\\\\]", "")
  )
}

from CfgNode pred, SuccessorType t, CfgNode succ
where pred.getASuccessor(t) = succ
select fileOf(pred) as file, nodeStr(pred) as p, t.toString() as label, nodeStr(succ) as s
  order by file, p, label, s
