import ada
import codeql.ada.controlflow.Guards
import codeql.ada.controlflow.ControlFlowGraph

/** Gets the first line of the statement `bb` starts in, for a readable key. */
string stmtAt(BasicBlock bb) {
  exists(Stmt s, int l |
    bb.getANode().isBefore(s) and
    s.getLocation().hasLocationInfo(_, l, _, _, _) and
    result = s.getAPrimaryQlClass() + "@" + l
  )
}

query predicate controls(Guard g, boolean branch, string stmt) {
  exists(BasicBlock bb | g.controls(bb, branch) and stmt = stmtAt(bb))
}

/** The ranges and nullness that a guard on a variable's read implies, as `valueControls`. */
query predicate valueControls(Guard g, string value, string stmt) {
  exists(BasicBlock bb, GuardValue v |
    g.valueControls(bb, v) and
    stmt = stmtAt(bb) and
    value = v.toString() and
    (exists(int k, boolean upper | v.isIntRange(k, upper)) or v.isNullness(_))
  )
}
