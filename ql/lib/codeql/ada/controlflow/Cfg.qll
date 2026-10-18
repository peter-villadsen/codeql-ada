/**
 * DEPRECATED: use `codeql.ada.controlflow.ControlFlowGraph`.
 *
 * The names of the control-flow graph before it moved to the shared
 * `codeql.controlflow.ControlFlowGraph` library (0.4.0), kept for one release. They
 * are views of the new graph, which has "before" and "after" nodes the old one did not
 * have: `AstCfgNode` is a node that represents its AST node (`injects`), as before;
 * `CfgNode` is any node.
 */

import codeql.controlflow.SuccessorType
private import ControlFlowGraph as G

/** DEPRECATED: use `ControlFlowGraph::CfgScope`. */
deprecated final class CfgScope = G::CfgScope;

/** DEPRECATED: use `ControlFlowGraph::ControlFlowNode`. */
deprecated class CfgNode extends G::ControlFlowNode {
  /** DEPRECATED: use `getEnclosingCallable()`. Gets the scope of this node. */
  G::CfgScope getScope() { result = this.getEnclosingCallable() }

  /** Gets a predecessor of this node along an edge of type `t`. */
  CfgNode getAPredecessor(SuccessorType t) { this = result.getASuccessor(t) }
}

/** DEPRECATED: use `ControlFlow::EntryNode`. */
deprecated class EntryNode extends CfgNode instanceof G::ControlFlow::EntryNode { }

/** DEPRECATED: use `ControlFlow::ExitNode`. */
deprecated class ExitNode extends CfgNode instanceof G::ControlFlow::ExitNode { }

/** DEPRECATED: use `ControlFlow::NormalExitNode` or `ControlFlow::ExceptionalExitNode`. */
deprecated class AnnotatedExitNode extends CfgNode instanceof G::ControlFlow::AnnotatedExitNode {
  /** Holds if this is the exit for normal completion. */
  predicate isNormal() { this instanceof G::ControlFlow::NormalExitNode }
}

/** DEPRECATED: use a `ControlFlowNode` that `injects` its AST node. */
deprecated class AstCfgNode extends CfgNode {
  AstCfgNode() { this.injects(_) }
}
