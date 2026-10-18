/**
 * Feasible paths through `finally` parts (`PathReachability`): the nodes the graph
 * reaches from a scope's entry that no feasible path does — where a `finally` part's end
 * continues a way it was not entered.
 */

import ada
import codeql.ada.controlflow.PathReachability
import codeql.ada.test.CfgAnnotations

module FromEntry implements PathReachability::ConfigSig {
  predicate isSource(ControlFlowNode n) { n instanceof ControlFlow::EntryNode }

  predicate isSink(ControlFlowNode n) { none() }
}

query predicate infeasible(string node) {
  exists(ControlFlowNode n | not PathReachability::Make<FromEntry>::reached(n) and node = nodeKey(n))
}
