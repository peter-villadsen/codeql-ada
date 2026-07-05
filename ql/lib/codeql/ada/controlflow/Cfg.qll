/**
 * Provides the Ada control-flow graph (CFG).
 *
 * The CFG is built on the shared `codeql/controlflow` framework (D-013) and is
 * exposed here as a stable public API. Each CFG *scope* (a subprogram, task,
 * entry, or package body) has its own graph running from an entry node to an
 * exit node; nodes correspond to evaluated AST elements and directed edges,
 * labelled with a `SuccessorType`, model possible control transfers.
 *
 * ## API summary (referenced by later Phase 7 tasks)
 *
 * - `CfgNode` — a node in the CFG. Key members:
 *   - `getASuccessor()` / `getASuccessor(SuccessorType t)` — outgoing edges.
 *   - `getAPredecessor()` / `getAPredecessor(SuccessorType t)` — incoming edges.
 *   - `getScope()` — the enclosing `CfgScope`.
 *   - `getLocation()` — source location.
 *   - `getAstNode()` — the underlying `Raw::AdaNode` (none for entry/exit nodes).
 * - `CfgScope` — a scope with its own graph (`Scopes::CfgScope`).
 * - `SuccessorType` and its subclasses (`DirectSuccessor`, `BooleanSuccessor`,
 *   `ReturnSuccessor`, `ExceptionSuccessor`, …) — edge labels.
 * - `ExprCfgNode` / `AstCfgNode` and the entry/exit node classes come from the
 *   framework's `Make` output that is re-exported below.
 * - `BasicBlocks` — the dominance/post-dominance submodule, reused by Task 7.6.
 * - `PrintCfg` output is produced via the framework's `PrintGraph` interface,
 *   wired up by the Task 7.5 test harness.
 *
 * Node granularity and edge structure per construct are documented in
 * `docs/cfg-design.md`.
 */

import codeql.controlflow.Cfg
import codeql.controlflow.SuccessorType
private import internal.ControlFlowGraphImpl
private import codeql.ada.ast.internal.Raw

/** A control flow graph scope: an Ada body with its own graph. */
final class CfgScope = Scopes::CfgScope;

/** A node in the Ada control-flow graph. */
final class CfgNode = CfgImpl::Node;

/** The entry node of a CFG scope. */
final class EntryNode = CfgImpl::EntryNode;

/** An exit node of a CFG scope. */
final class ExitNode = CfgImpl::ExitNode;

/**
 * An exit node of a CFG scope, annotated with whether it was reached via a
 * normal (`getAMatchingSuccessorType()` not an `ExceptionSuccessor`/
 * `ExitSuccessor`) or abnormal completion. Note that both fall-through
 * (`DirectSuccessor`) and explicit `return` (`ReturnSuccessor`) count as
 * normal here; distinguish them, if needed, by the type of the edge reaching
 * this node (see `FunctionMissingReturn.ql` for a worked example).
 */
final class AnnotatedExitNode = CfgImpl::AnnotatedExitNode;

/** A node corresponding to an AST element. */
final class AstCfgNode = CfgImpl::AstCfgNode;

/**
 * Gets the AST node first executed when `n` is entered (e.g. the guard of an
 * `if`, or `n` itself for a straight-line statement). This is a *structural*
 * predicate: it always has a result for any node with executable content,
 * regardless of whether `n` itself is reachable. Combine with `AstCfgNode` to
 * test reachability of a compound statement whose own node in the CFG
 * represents only its normal-completion join point (e.g. an `if` all of
 * whose branches return has no `AstCfgNode` for the `IfStmt` itself, even
 * though it plainly executes) -- see `UnreachableStatement.ql`.
 */
Raw::AdaNode getAControlFlowEntryNode(Raw::AdaNode n) { result = CfgImpl::getAControlFlowEntryNode(n) }
