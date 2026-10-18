/**
 * Provides classes for working with basic blocks of the control-flow graph.
 *
 * A basic block is a maximal sequence of control-flow nodes that always run one after
 * another. The blocks, and their dominance and post-dominance, come from the shared
 * `codeql.controlflow.BasicBlock` library over `codeql.ada.controlflow.ControlFlowGraph`.
 */

import ControlFlowGraph

/** A basic block that ends at its scope's exit node. */
class ExitBlock extends BasicBlock {
  ExitBlock() { this.getLastNode() instanceof ControlFlow::ExitNode }
}
