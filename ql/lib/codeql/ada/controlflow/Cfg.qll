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

/** A control flow graph scope: an Ada body with its own graph. */
final class CfgScope = Scopes::CfgScope;

/** A node in the Ada control-flow graph. */
final class CfgNode = CfgImpl::Node;

/** The entry node of a CFG scope. */
final class EntryNode = CfgImpl::EntryNode;

/** An exit node of a CFG scope. */
final class ExitNode = CfgImpl::ExitNode;

/** A node corresponding to an AST element. */
final class AstCfgNode = CfgImpl::AstCfgNode;
