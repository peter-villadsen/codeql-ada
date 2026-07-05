/**
 * Provides basic blocks and dominance/post-dominance over the Ada control-flow
 * graph, re-exporting the shared `codeql/controlflow` framework's basic-block
 * construction (see the API summary in `codeql.ada.controlflow.Cfg`).
 */

private import internal.ControlFlowGraphImpl

/** A maximal straight-line sequence of CFG nodes without branches or joins. */
final class BasicBlock = CfgImpl::BasicBlocks::BasicBlock;

/** A basic block whose first node is a CFG scope's entry node. */
final class EntryBasicBlock = CfgImpl::BasicBlocks::EntryBasicBlock;

/** A basic block that contains an annotated (normal or abnormal) exit node. */
final class AnnotatedExitBasicBlock = CfgImpl::BasicBlocks::AnnotatedExitBasicBlock;

/** A basic block whose last node is a CFG scope's (unannotated) exit node. */
final class ExitBasicBlock = CfgImpl::BasicBlocks::ExitBasicBlock;

/** A basic block with more than one predecessor. */
final class JoinBasicBlock = CfgImpl::BasicBlocks::JoinBasicBlock;

/** A basic block that is an immediate predecessor of a join block. */
final class JoinPredecessorBasicBlock = CfgImpl::BasicBlocks::JoinPredecessorBasicBlock;

/** A basic block that terminates in a condition, splitting subsequent control flow. */
final class ConditionBasicBlock = CfgImpl::BasicBlocks::ConditionBasicBlock;

/** Holds if `bb1 -> bb2` is a dominating edge (see `BasicBlock.edgeDominates`). */
predicate dominatingEdge = CfgImpl::BasicBlocks::dominatingEdge/2;
