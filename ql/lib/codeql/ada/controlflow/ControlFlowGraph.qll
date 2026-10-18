/**
 * Provides classes representing the control-flow graph within Ada bodies.
 *
 * Each `CfgScope` (a subprogram, expression function, task, entry or package body) has
 * its own graph, from a `ControlFlow::EntryNode` to a `ControlFlow::ExitNode` through a
 * `ControlFlow::NormalExitNode` or `ControlFlow::ExceptionalExitNode`. The graph is
 * built on the shared `codeql.controlflow.ControlFlowGraph` library (D-029), as CodeQL
 * for Java's is; `docs/cfg-design.md` specifies it construct by construct.
 *
 * Every evaluated AST node has one node that represents it (`injects`, `asExpr`,
 * `asStmt`): for an expression with operands, a call or an assignment it follows the
 * parts; for other statements it precedes them. Most AST nodes also have a "before" and
 * an "after" node (`isBefore`, `isAfter`); a condition has one "after" node per value
 * (`isAfterTrue`, `isAfterFalse`). Only nodes reachable from the entry are
 * `ControlFlowNode`s.
 *
 * ```ql
 * import ada
 * import codeql.ada.controlflow.ControlFlowGraph
 *
 * from Stmt s
 * where not exists(ControlFlowNode n | n.isBefore(s))
 * select s, "This statement is never reached."
 * ```
 */

import codeql.controlflow.SuccessorType
private import internal.ControlFlowGraphImpl as Impl

/** A body with its own control-flow graph: a subprogram, expression function, task, entry or package body. */
final class CfgScope = Impl::CfgScope;

/** A node in the control-flow graph, reachable from its scope's entry. */
final class ControlFlowNode = Impl::ControlFlowNode;

/** Provides the entry and exit nodes of the control-flow graph. */
module ControlFlow = Impl::ControlFlow;

/** A control-flow node that branches on a Boolean condition. */
final class ConditionNode = Impl::ConditionNode;

/** A basic block: a maximal sequence of nodes that always run one after another. */
final class BasicBlock = Impl::BasicBlock;

/** The basic block that starts at a scope's entry node. */
final class EntryBasicBlock = Impl::EntryBasicBlock;

/**
 * Holds if the edge from `bb1` to `bb2` dominates `bb2`: every path from the entry to
 * `bb2` goes through it.
 */
predicate dominatingEdge = Impl::dominatingEdge/2;
