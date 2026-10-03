/**
 * Ada instantiation of the shared `codeql/controlflow` CFG framework (D-013).
 *
 * This module implements the framework's `InputSig` over the Libadalang raw AST
 * (`Raw.qll`) and builds the control-flow graph by extending `ControlFlowTree`
 * once per control-relevant construct, per the mapping in `docs/cfg-design.md`.
 *
 * Phase 7.2 covers **scopes + straight-line code**: subprogram/task/entry/package
 * bodies as CFG scopes, statement sequencing, null/assignment/call/return/raise
 * statements, calls, and generic post-order expression evaluation. Branching,
 * loops, exceptions and short-circuit operators arrive in tasks 7.3/7.4; until
 * then every not-yet-modelled statement is an opaque leaf (see `OpaqueStmtTree`).
 *
 * `AstNode = Raw::AdaNode` and `Location = Raw::Location` are used directly as
 * aliases (no wrappers); `Raw::Location` satisfies `LocationSig` via the
 * `getStartLine`/`getStartColumn`/`getEndLine`/`getEndColumn` accessors emitted
 * by the generator.
 */

import codeql.controlflow.Cfg
private import codeql.controlflow.SuccessorType
private import codeql.ada.ast.internal.Raw
import Completion

/** The location type: `Raw::Location` satisfies `LocationSig` (see module doc). */
private class Location = Raw::Location;

/**
 * Provides the CFG scopes. Each scope gets its own disconnected graph with a
 * single entry and a single (possibly annotated) exit. Nested bodies are their
 * own scopes.
 */
module Scopes {
  /** A control flow graph scope: an Ada body with executable content. */
  class CfgScope extends Raw::AdaNode {
    CfgScope() {
      this instanceof Raw::SubpBody or
      this instanceof Raw::ExprFunction or
      this instanceof Raw::TaskBody or
      this instanceof Raw::EntryBody or
      this instanceof Raw::PackageBody
    }

    /**
     * Gets the body content executed for this scope.
     *
     * For an expression function that is the return expression. For every other
     * scope it is the body node itself, which `BodyTree` sequences as
     * "elaborate the declarative part, then run the statements" — so a local
     * object's initializer is part of the graph, exactly as in a `declare`
     * block.
     */
    private Raw::AdaNode getBody() {
      result = this.(Raw::ExprFunction).getExpr()
      or
      not this instanceof Raw::ExprFunction and result = this
    }

    /** Holds if `first` is executed first when entering this scope. */
    predicate scopeFirst(Raw::AdaNode first) { first(this.getBody(), first) }

    /** Holds if this scope is exited when `last` finishes with completion `c`. */
    predicate scopeLast(Raw::AdaNode last, Completion c) { last(this.getBody(), last, c) }
  }
}

/** Gets the innermost CFG scope enclosing `n`. */
Scopes::CfgScope getEnclosingCfgScope(Raw::AdaNode n) {
  result = n.getParent+() and
  not exists(Scopes::CfgScope closer | closer = n.getParent+() and result = closer.getParent+())
}

/** The `InputSig` implementation consumed by `Make`. */
private module CfgInput implements InputSig<Location> {
  private import Completion as C

  class AstNode = Raw::AdaNode;

  class Completion = C::Completion;

  predicate completionIsNormal = C::completionIsNormal/1;

  predicate completionIsSimple = C::completionIsSimple/1;

  predicate completionIsValidFor = C::completionIsValidFor/2;

  class CfgScope = Scopes::CfgScope;

  CfgScope getCfgScope(Raw::AdaNode n) { result = getEnclosingCfgScope(n) }

  predicate scopeFirst(CfgScope scope, Raw::AdaNode first) { scope.scopeFirst(first) }

  predicate scopeLast(CfgScope scope, Raw::AdaNode last, Completion c) { scope.scopeLast(last, c) }

  SuccessorType getAMatchingSuccessorType(Completion c) { result = c.getAMatchingSuccessorType() }

  predicate successorTypeIsCondition(SuccessorType t) { t instanceof BooleanSuccessor }

  private predicate id(Raw::AdaNode x, Raw::AdaNode y) { x = y }

  private predicate idOfDbAstNode(Raw::AdaNode x, int y) = equivalenceRelation(id/2)(x, y)

  int idOfAstNode(Raw::AdaNode node) { idOfDbAstNode(node, result) }

  int idOfCfgScope(CfgScope node) { result = idOfAstNode(node) }
}

module CfgImpl = Make<Location, CfgInput>;

import CfgImpl

// ---------------------------------------------------------------------------
// Control-flow trees (per-construct structure). See docs/cfg-design.md.
// ---------------------------------------------------------------------------

/**
 * A statement sequence. Transparent: entering the list enters its first
 * statement, and the list finishes when its last statement finishes normally.
 * Abnormal completions of any statement propagate outward (default
 * `propagatesAbnormal` on `StandardTree`).
 */
class StmtListTree extends StandardTree instanceof Raw::StmtList {
  override Raw::AdaNode getChildNode(int i) { result = super.getChild(i) }

  override predicate first(Raw::AdaNode first) { first(this.getFirstChildTree(), first) }

  override predicate last(Raw::AdaNode last, Completion c) {
    last(this.getLastChildTree(), last, c) and completionIsNormal(c)
  }
}

/**
 * A handled statement sequence (`… exception when … => …`). The protected
 * statements run; a `RaiseCompletion` anywhere in the region has an edge to the
 * start of every handler (v1 does not match exception identities). A raise
 * escapes the sequence only when there is no `when others` handler. A handler
 * body finishing normally continues after the sequence.
 */
class HandledStmtsTree extends ControlFlowTree instanceof Raw::HandledStmts {
  private Raw::ExceptionHandler aHandler() { result = super.getExceptions().getChild(_) }

  override predicate first(Raw::AdaNode f) { first(super.getStmts(), f) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    // handler bodies are not themselves protected: their abnormal completions escape
    child = this.aHandler().getStmts()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    last(super.getStmts(), pred, c) and
    c instanceof RaiseCompletion and
    first(this.aHandler().getStmts(), succ)
  }

  override predicate last(Raw::AdaNode l, Completion c) {
    // protected region completes normally
    last(super.getStmts(), l, c) and completionIsNormal(c)
    or
    // protected region completes abnormally: return/exit/goto always escape; a
    // raise escapes only when it is not caught by a `when others` handler
    last(super.getStmts(), l, c) and
    not completionIsNormal(c) and
    (not c instanceof RaiseCompletion or not hasOthersHandler(this))
    or
    // a handler body finishing normally → continue after the sequence
    last(this.aHandler().getStmts(), l, c) and completionIsNormal(c)
  }
}

/** Holds if `hs` has a `when others =>` exception handler. */
private predicate hasOthersHandler(Raw::HandledStmts hs) {
  exists(Raw::ExceptionHandler h | h = hs.getExceptions().getChild(_) |
    h.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator
  )
}

/** A `null;` statement: a leaf that completes normally. */
class NullStmtTree extends LeafTree instanceof Raw::NullStmt { }

/**
 * A pragma among statements (`pragma Assert (...)`, `pragma Loop_Invariant (...)`): a
 * leaf that completes normally; its arguments are not evaluated in the graph. A
 * pragma is not a `Stmt`, and before Task 9.6 it had no tree at all, so the
 * statement chain broke there and everything after it was unreachable.
 */
class PragmaInStmtsTree extends LeafTree instanceof Raw::PragmaNode {
  PragmaInStmtsTree() { this.getParent() instanceof Raw::StmtList }
}

/** An assignment: evaluate RHS, then LHS, then the statement (post-order). */
class AssignStmtTree extends StandardPostOrderTree instanceof Raw::AssignStmt {
  override Raw::AdaNode getChildNode(int i) {
    i = 0 and result = super.getExpr()
    or
    i = 1 and result = super.getDest()
  }
}

/** A call statement: evaluate the call, then the statement (may also raise). */
class CallStmtTree extends StandardPostOrderTree instanceof Raw::CallStmt {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getCall() }
}

/** A call expression: evaluate name then suffix, then the node (may also raise). */
class CallExprTree extends StandardPostOrderTree instanceof Raw::CallExpr {
  override Raw::AdaNode getChildNode(int i) {
    i = 0 and result = super.getName()
    or
    i = 1 and result = super.getSuffix()
  }
}

/**
 * A `return` statement: evaluate the (optional) return expression, then the
 * statement, which completes with `ReturnCompletion` (never normally).
 */
class ReturnStmtTree extends StandardPostOrderTree instanceof Raw::ReturnStmt {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getReturnExpr() }
}

/**
 * A `raise` statement: evaluate the (optional) exception name, then the
 * statement, which completes with `RaiseCompletion` (never normally).
 */
class RaiseStmtTree extends StandardPostOrderTree instanceof Raw::RaiseStmt {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getExceptionName() }
}

/**
 * Generic left-to-right post-order evaluation for any remaining AST node that
 * can appear inside an expression context (identifiers, literals, dotted
 * names, operators, aggregates, argument lists, …). Terminals become leaves.
 * Statements, statement sequences, calls (handled above) and bodies (scopes)
 * are excluded.
 */
class GenericPostOrderTree extends StandardPostOrderTree instanceof Raw::AdaNode {
  GenericPostOrderTree() {
    exprLike(this) and
    not this instanceof Raw::CallExpr and
    // conditional expressions and short-circuit operators have their own trees
    not this instanceof Raw::IfExpr and
    not this instanceof Raw::CaseExpr and
    not this instanceof Raw::CaseExprAlternative and
    not isShortCircuitBinOp(this)
  }

  override Raw::AdaNode getChildNode(int i) { result = super.getChild(i) and exprLike(result) }
}

/** Holds if `n` is a short-circuit (`and then` / `or else`) binary operation. */
private predicate isShortCircuitBinOp(Raw::AdaNode n) {
  isShortCircuitOp(n.(Raw::BinOp).getOp())
}

/**
 * Holds if `n` is an expression or argument-list container that participates in
 * value evaluation — as opposed to operators (not executed), declarations, or
 * the structural parts of statements (which their owning trees handle directly).
 * A `ConcatOperandList` holds every operand of an `&` chain after the first
 * (`A & B & C` is one `ConcatOp`), so without it those operands are never
 * evaluated. Likewise an `ExprAlternativesList` holds a membership test's
 * alternatives (`X in A | B`); they are modelled as all evaluated, left to
 * right, although Ada stops at the first that matches (RM 4.5.2(27/3)) --
 * an over-approximation, like evaluating both branches' operands would be.
 */
private predicate exprLike(Raw::AdaNode n) {
  (
    n instanceof Raw::Expr or
    n instanceof Raw::AssocList or
    n instanceof Raw::BasicAssoc or
    n instanceof Raw::ConcatOperandList or
    n instanceof Raw::ExprAlternativesList
  ) and
  not n instanceof Raw::Op
}

/**
 * Fallback for statements not yet modelled with their own control-flow tree
 * (branching, loops, blocks, tasking, goto, …). Treated as an opaque leaf that
 * completes normally. Each of these gets a dedicated tree in tasks 7.3/7.4, at
 * which point it drops out of this fallback.
 */
class OpaqueStmtTree extends LeafTree instanceof Raw::Stmt {
  OpaqueStmtTree() {
    not this instanceof Raw::NullStmt and
    not this instanceof Raw::AssignStmt and
    not this instanceof Raw::CallStmt and
    not this instanceof Raw::ReturnStmt and
    not this instanceof Raw::RaiseStmt and
    not this instanceof Raw::IfStmt and
    not this instanceof Raw::CaseStmt and
    not this instanceof Raw::BaseLoopStmt and
    not this instanceof Raw::NamedStmt and
    not this instanceof Raw::ExitStmt and
    not this instanceof Raw::GotoStmt and
    not this instanceof Raw::Label and
    not this instanceof Raw::BlockStmt and
    not this instanceof Raw::ExtendedReturnStmt and
    not this instanceof Raw::SelectStmt and
    // only `accept … do … end` has its own tree; a plain `accept E;` has no
    // statements to wire and stays an opaque leaf here. Excluding all of
    // `AcceptStmt` would leave it covered by no tree at all, so it would vanish
    // from the graph and be reported as unreachable.
    not this instanceof Raw::AcceptStmtWithStmts
  }
}

// ---------------------------------------------------------------------------
// Branching, loops, exit, goto, blocks (Task 7.3). See docs/cfg-design.md.
// ---------------------------------------------------------------------------

/**
 * An `if` statement with optional `elsif`/`else` parts. Modelled as a
 * post-order tree whose node is the join reached after any branch: the
 * controlling condition of guard `i` branches `true` to guard `i`'s statements
 * and `false` to the next guard's condition (or the `else`, or the join).
 */
class IfStmtTree extends PostOrderTree instanceof Raw::IfStmt {
  /** Gets the condition of guard `i` (0 = the `if`, 1.. = the `elsif`s). */
  private Raw::Expr guardCond(int i) {
    i = 0 and result = super.getCondExpr()
    or
    result = super.getAlternatives().getChild(i - 1).(Raw::ElsifStmtPart).getCondExpr()
  }

  /** Gets the statements of guard `i`. */
  private Raw::StmtList guardBody(int i) {
    i = 0 and result = super.getThenStmts()
    or
    result = super.getAlternatives().getChild(i - 1).(Raw::ElsifStmtPart).getStmts()
  }

  private int numGuards() { result = 1 + count(super.getAlternatives().getChild(_)) }

  private predicate hasElse() { exists(super.getElsePart()) }

  private Raw::StmtList elseBody() { result = super.getElsePart().getStmts() }

  override predicate first(Raw::AdaNode node) { first(this.guardCond(0), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = this.guardCond(_) or child = this.guardBody(_) or child = this.elseBody()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    exists(int i, boolean b | last(this.guardCond(i), pred, c) and b = c.(BooleanCompletion).getValue() |
      // condition true → this guard's statements
      b = true and first(this.guardBody(i), succ)
      or
      // condition false → next guard's condition
      b = false and first(this.guardCond(i + 1), succ)
      or
      // condition false, no further guard → else statements
      b = false and i + 1 = this.numGuards() and first(this.elseBody(), succ)
      or
      // condition false, no further guard, no else → join
      b = false and i + 1 = this.numGuards() and not this.hasElse() and succ = this
    )
    or
    // any guard body finishing normally → join
    last(this.guardBody(_), pred, c) and completionIsNormal(c) and succ = this
    or
    // else body finishing normally → join
    last(this.elseBody(), pred, c) and completionIsNormal(c) and succ = this
  }
}

/**
 * A `case` statement. The selector expression branches to exactly one
 * alternative's statements (v1: an over-approximate branch to every
 * alternative); each alternative's statements converge on the join node.
 */
class CaseStmtTree extends PostOrderTree instanceof Raw::CaseStmt {
  private Raw::StmtList altBody() {
    result = super.getAlternatives().getChild(_).(Raw::CaseStmtAlternative).getStmts()
  }

  override predicate first(Raw::AdaNode node) { first(super.getExpr(), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    // the selector as well as the bodies: a selector that can raise must
    // propagate that completion, as an `if`'s guard condition does
    child = super.getExpr() or child = this.altBody()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // selector → each alternative's statements
    last(super.getExpr(), pred, c) and completionIsNormal(c) and first(this.altBody(), succ)
    or
    // each alternative → join
    last(this.altBody(), pred, c) and completionIsNormal(c) and succ = this
  }
}

/**
 * A plain `loop … end loop`. The body loops back to itself; the loop node
 * (post-order self) is reached only by an `exit` (see `ExitStmtTree`), so a
 * loop with no exit/return/raise is correctly infinite.
 */
class LoopStmtTree extends PostOrderTree instanceof Raw::LoopStmt {
  override predicate first(Raw::AdaNode node) { first(super.getStmts(), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) { child = super.getStmts() }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    last(super.getStmts(), pred, c) and completionIsNormal(c) and first(super.getStmts(), succ)
  }
}

/** A `while` loop: condition true → body → condition; condition false → exit. */
class WhileLoopStmtTree extends PostOrderTree instanceof Raw::WhileLoopStmt {
  private Raw::Expr cond() { result = super.getSpec().(Raw::WhileLoopSpec).getExpr() }

  override predicate first(Raw::AdaNode node) { first(this.cond(), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = super.getStmts() or child = this.cond()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // condition true → body
    last(this.cond(), pred, c) and c.(BooleanCompletion).getValue() = true and
    first(super.getStmts(), succ)
    or
    // condition false → exit the loop (join)
    last(this.cond(), pred, c) and c.(BooleanCompletion).getValue() = false and succ = this
    or
    // body → back to condition
    last(super.getStmts(), pred, c) and completionIsNormal(c) and first(this.cond(), succ)
  }
}

/**
 * A `for` loop. The iteration mechanism is modelled opaquely (D-013): the
 * iterable is evaluated once, then control may enter the body or skip the loop,
 * and after each body iteration may loop again or exit.
 */
class ForLoopStmtTree extends PostOrderTree instanceof Raw::ForLoopStmt {
  private Raw::AdaNode iter() { result = super.getSpec().(Raw::ForLoopSpec).getIterExpr() }

  override predicate first(Raw::AdaNode node) { first(this.iter(), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = super.getStmts() or child = this.iter()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // iterable evaluated → enter body (has elements) or skip loop (empty)
    last(this.iter(), pred, c) and
    completionIsNormal(c) and
    (first(super.getStmts(), succ) or succ = this)
    or
    // after an iteration → loop again or exit
    last(super.getStmts(), pred, c) and
    completionIsNormal(c) and
    (first(super.getStmts(), succ) or succ = this)
  }
}

/**
 * The iteration part of a `for` loop when it is a subtype indication rather than an
 * expression: `for I in Natural range A .. B`. Evaluates the range expression of
 * its constraint, if any, then the indication itself. Before Task 9.6 it had no
 * tree, so such a loop had no first node and it, and everything after it, was
 * unreachable.
 */
class ForLoopSubtypeIndicationTree extends StandardPostOrderTree instanceof Raw::SubtypeIndication
{
  ForLoopSubtypeIndicationTree() { this = any(Raw::ForLoopSpec s).getIterExpr() }

  override Raw::AdaNode getChildNode(int i) {
    i = 0 and result = super.getConstraint().(Raw::RangeConstraint).getRange().getRange()
  }
}

/** A named statement (`Outer: loop …`): transparent to the wrapped statement. */
class NamedStmtTree extends StandardTree instanceof Raw::NamedStmt {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getStmt() }

  override predicate first(Raw::AdaNode f) { first(super.getStmt(), f) }

  override predicate last(Raw::AdaNode l, Completion c) { last(super.getStmt(), l, c) }
}

/**
 * An `exit` statement. A direct jump to the point after the targeted loop (the
 * loop's post-order node). With a condition: `true` takes the exit, `false`
 * falls through to the next statement.
 */
class ExitStmtTree extends ControlFlowTree instanceof Raw::ExitStmt {
  override predicate first(Raw::AdaNode f) {
    first(super.getCondExpr(), f)
    or
    not exists(super.getCondExpr()) and f = this
  }

  override predicate propagatesAbnormal(Raw::AdaNode child) { child = super.getCondExpr() }

  override predicate last(Raw::AdaNode l, Completion c) {
    // conditional exit not taken → falls through on `false`
    last(super.getCondExpr(), l, c) and c.(BooleanCompletion).getValue() = false
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // condition true → reach the exit node
    last(super.getCondExpr(), pred, c) and c.(BooleanCompletion).getValue() = true and succ = this
    or
    // exit taken → jump to the target loop node
    pred = this and c instanceof ExitCompletion and succ = exitTargetLoop(this)
  }
}

/** A `goto` statement: a direct jump to the matching label in the same scope. */
class GotoStmtTree extends ControlFlowTree instanceof Raw::GotoStmt {
  override predicate first(Raw::AdaNode f) { f = this }

  override predicate propagatesAbnormal(Raw::AdaNode child) { none() }

  override predicate last(Raw::AdaNode l, Completion c) { none() }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    pred = this and c instanceof GotoCompletion and first(gotoTargetLabel(this), succ)
  }
}

/** A statement label (`<<L>>`): a leaf control passes through. */
class LabelTree extends LeafTree instanceof Raw::Label { }

/** A `begin … end` block: transparent to its handled statement sequence. */
class BeginBlockTree extends StandardTree instanceof Raw::BeginBlock {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getStmts() }

  override predicate first(Raw::AdaNode f) { first(this.getFirstChildTree(), f) }

  override predicate last(Raw::AdaNode l, Completion c) {
    last(this.getLastChildTree(), l, c) and completionIsNormal(c)
  }
}

// ---------------------------------------------------------------------------
// Elaboration of declarative parts, shared by `declare` blocks and bodies.
// ---------------------------------------------------------------------------

/** Gets the `i`th declaration of `part`. */
private Raw::AdaNode declAt(Raw::DeclarativePart part, int i) {
  result = part.getDecls().getChild(i)
}

/**
 * Gets the initializer evaluated when elaborating the `i`th declaration of
 * `part`, if any.
 *
 * Only object declarations are elaborated: a named number (`K : constant := 3`)
 * is a `NumberDecl` whose value is static, and the declarative parts of nested
 * packages are a documented gap (see `docs/cfg-design.md`).
 */
private Raw::Expr elaboratedInitializer(Raw::DeclarativePart part, int i) {
  result = declAt(part, i).(Raw::ObjectDecl).getDefaultExpr()
}

/** Gets the number of declarations in `part`, or 0 if there is no such part. */
bindingset[part]
private int declCount(Raw::DeclarativePart part) { result = count(declAt(part, _)) }

/**
 * A `declare … begin … end` block: elaborate the declarative part (object
 * declaration initializers are evaluated, in declaration order) then run the
 * handled statements. Transparent — the block itself is never a node.
 */
class DeclBlockTree extends StandardTree instanceof Raw::DeclBlock {
  override Raw::AdaNode getChildNode(int i) {
    // object-declaration initializers, in declaration order …
    result = elaboratedInitializer(super.getDecls(), i)
    or
    // … then the handled statements
    i = declCount(super.getDecls()) and result = super.getStmts()
  }

  override predicate first(Raw::AdaNode f) { first(this.getFirstChildTree(), f) }

  override predicate last(Raw::AdaNode l, Completion c) {
    last(this.getLastChildTree(), l, c) and completionIsNormal(c)
  }
}

/** Gets the declarative part of body `b`. */
private Raw::DeclarativePart bodyDecls(Raw::AdaNode b) {
  result = b.(Raw::SubpBody).getDecls() or
  result = b.(Raw::PackageBody).getDecls() or
  result = b.(Raw::TaskBody).getDecls() or
  result = b.(Raw::EntryBody).getDecls()
}

/** Gets the handled statement sequence of body `b`. */
private Raw::HandledStmts bodyStmts(Raw::AdaNode b) {
  result = b.(Raw::SubpBody).getStmts() or
  result = b.(Raw::PackageBody).getStmts() or
  result = b.(Raw::TaskBody).getStmts() or
  result = b.(Raw::EntryBody).getStmts()
}

/**
 * A body with a declarative part — a subprogram, package, task or entry body.
 * Elaborates the object-declaration initializers in declaration order, then
 * runs the statements, exactly as a `declare` block does. An entry body's
 * barrier is evaluated first of all, since it is evaluated before the body is
 * entered.
 *
 * Transparent: the body node itself is never in the graph. It is the scope's
 * `getBody()`, so `scopeFirst` enters the first elaborated initializer (or the
 * first statement when there is nothing to elaborate) and `scopeLast` picks up
 * both the statements' normal completion and, through `propagatesAbnormal`,
 * every `return`/`raise` escaping either part.
 */
class BodyTree extends StandardTree instanceof Raw::AdaNode {
  BodyTree() {
    this instanceof Raw::SubpBody or
    this instanceof Raw::PackageBody or
    this instanceof Raw::TaskBody or
    this instanceof Raw::EntryBody
  }

  override Raw::AdaNode getChildNode(int i) {
    i = -1 and result = this.(Raw::EntryBody).getBarrier()
    or
    result = elaboratedInitializer(bodyDecls(this), i)
    or
    i = declCount(bodyDecls(this)) and result = bodyStmts(this)
  }

  override predicate first(Raw::AdaNode f) { first(this.getFirstChildTree(), f) }

  override predicate last(Raw::AdaNode l, Completion c) {
    last(this.getLastChildTree(), l, c) and completionIsNormal(c)
  }
}

// ---------------------------------------------------------------------------
// Exceptions, short-circuit, conditional expressions, extended return, tasking
// (Task 7.4). See docs/cfg-design.md.
// ---------------------------------------------------------------------------

/**
 * A short-circuit boolean operation (`and then` / `or else`). The left operand
 * is evaluated in a Boolean context; depending on its value the right operand
 * is either evaluated or skipped, and the result converges on the node.
 */
class ShortCircuitTree extends PostOrderTree instanceof Raw::BinOp {
  ShortCircuitTree() { isShortCircuitOp(super.getOp()) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = super.getLeft() or child = super.getRight()
  }

  override predicate first(Raw::AdaNode node) { first(super.getLeft(), node) }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // `and then`: left true → evaluate right; left false → short-circuit to node
    super.getOp() instanceof Raw::OpAndThen and
    exists(boolean b | last(super.getLeft(), pred, c) and b = c.(BooleanCompletion).getValue() |
      b = true and first(super.getRight(), succ)
      or
      b = false and succ = this
    )
    or
    // `or else`: left false → evaluate right; left true → short-circuit to node
    super.getOp() instanceof Raw::OpOrElse and
    exists(boolean b | last(super.getLeft(), pred, c) and b = c.(BooleanCompletion).getValue() |
      b = false and first(super.getRight(), succ)
      or
      b = true and succ = this
    )
    or
    // right operand evaluated → node
    last(super.getRight(), pred, c) and succ = this and completionIsNormal(c)
  }
}

/**
 * An `if` expression: the same branch shape as an `if` statement, but each
 * branch produces a value that converges on the expression node.
 */
class IfExprTree extends PostOrderTree instanceof Raw::IfExpr {
  private Raw::Expr guardCond(int i) {
    i = 0 and result = super.getCondExpr()
    or
    result = super.getAlternatives().getChild(i - 1).(Raw::ElsifExprPart).getCondExpr()
  }

  private Raw::Expr guardThen(int i) {
    i = 0 and result = super.getThenExpr()
    or
    result = super.getAlternatives().getChild(i - 1).(Raw::ElsifExprPart).getThenExpr()
  }

  private int numGuards() { result = 1 + count(super.getAlternatives().getChild(_)) }

  private Raw::Expr elseExpr() { result = super.getElseExpr() }

  override predicate first(Raw::AdaNode node) { first(this.guardCond(0), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = this.guardCond(_) or child = this.guardThen(_) or child = this.elseExpr()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    exists(int i, boolean b | last(this.guardCond(i), pred, c) and b = c.(BooleanCompletion).getValue() |
      b = true and first(this.guardThen(i), succ)
      or
      b = false and first(this.guardCond(i + 1), succ)
      or
      b = false and i + 1 = this.numGuards() and first(this.elseExpr(), succ)
      or
      b = false and i + 1 = this.numGuards() and not exists(this.elseExpr()) and succ = this
    )
    or
    last(this.guardThen(_), pred, c) and completionIsNormal(c) and succ = this
    or
    last(this.elseExpr(), pred, c) and completionIsNormal(c) and succ = this
  }
}

/** A `case` expression: like a `case` statement but each arm produces a value. */
class CaseExprTree extends PostOrderTree instanceof Raw::CaseExpr {
  private Raw::Expr altExpr() {
    result = super.getCases().getChild(_).(Raw::CaseExprAlternative).getExpr()
  }

  override predicate first(Raw::AdaNode node) { first(super.getExpr(), node) }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    // the selector as well as the arms -- see `CaseStmtTree`
    child = super.getExpr() or child = this.altExpr()
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    last(super.getExpr(), pred, c) and completionIsNormal(c) and first(this.altExpr(), succ)
    or
    last(this.altExpr(), pred, c) and completionIsNormal(c) and succ = this
  }
}

/**
 * An extended `return` statement (`return X : T := V do … end return`):
 * elaborate the object declaration, run the optional handled statements, then
 * complete with `ReturnCompletion`.
 */
class ExtendedReturnStmtTree extends ControlFlowTree instanceof Raw::ExtendedReturnStmt {
  private Raw::Expr initExpr() { result = super.getDecl().getDefaultExpr() }

  private Raw::HandledStmts stmts() { result = super.getStmts() }

  override predicate first(Raw::AdaNode node) {
    first(this.initExpr(), node)
    or
    not exists(this.initExpr()) and first(this.stmts(), node)
    or
    not exists(this.initExpr()) and not exists(this.stmts()) and node = this
  }

  override predicate propagatesAbnormal(Raw::AdaNode child) {
    child = this.initExpr() or child = this.stmts()
  }

  override predicate last(Raw::AdaNode l, Completion c) {
    l = this and c instanceof ReturnCompletion
  }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    // initializer evaluated → handled statements (or the return node if none)
    last(this.initExpr(), pred, c) and
    completionIsNormal(c) and
    (first(this.stmts(), succ) or not exists(this.stmts()) and succ = this)
    or
    // handled statements finished → the return node
    last(this.stmts(), pred, c) and completionIsNormal(c) and succ = this
  }
}

/** An `accept … do … end` statement: transparent to its handled statements. */
class AcceptStmtTree extends StandardTree instanceof Raw::AcceptStmtWithStmts {
  override Raw::AdaNode getChildNode(int i) { i = 0 and result = super.getStmts() }

  override predicate first(Raw::AdaNode f) { first(super.getStmts(), f) }

  override predicate last(Raw::AdaNode l, Completion c) { last(super.getStmts(), l, c) }
}

/**
 * A `select` statement (opaque, D-013): modelled like a `case` over its guarded
 * alternatives — control may enter any alternative's (or the `else` part's)
 * statements, which converge on the select node. Inter-task rendezvous and the
 * `terminate`/`abort` semantics are not modelled.
 */
class SelectStmtTree extends PostOrderTree instanceof Raw::SelectStmt {
  private Raw::StmtList branch() {
    result = super.getGuards().getChild(_).(Raw::SelectWhenPart).getStmts()
    or
    result = super.getElsePart().getStmts()
    or
    // the abortable part of `select … then abort …`; without this its
    // statements are in no branch and so appear unreachable
    result = super.getThenAbortPart().getStmts()
  }

  override predicate first(Raw::AdaNode node) { first(this.branch(), node) or this.enterNode(node) }

  private predicate enterNode(Raw::AdaNode node) {
    // if some alternative has no statements the select can complete immediately
    not exists(this.branch()) and node = this
  }

  override predicate propagatesAbnormal(Raw::AdaNode child) { child = this.branch() }

  override predicate succ(Raw::AdaNode pred, Raw::AdaNode succ, Completion c) {
    last(this.branch(), pred, c) and completionIsNormal(c) and succ = this
  }
}

// ---------------------------------------------------------------------------
// Jump-target resolution (exit → loop, goto → label). Labels and loop names
// are matched textually within the same CFG scope (see docs/cfg-design.md).
// ---------------------------------------------------------------------------

/** Gets the identifier text of a simple name. */
private string nameText(Raw::Name n) { result = n.(Raw::Identifier).getValue() }

/** Gets the declared name of a named loop (`Outer: loop …`), if any. */
private string loopDeclName(Raw::BaseLoopStmt loop) {
  exists(Raw::NamedStmt ns | ns.getStmt() = loop |
    result = nameText(ns.getDecl().getName().getName())
  )
}

/** Gets a loop that (properly) encloses `n`. */
private Raw::BaseLoopStmt enclosingLoop(Raw::AdaNode n) { result = n.getParent+() }

/** Gets the innermost loop enclosing `n`. */
private Raw::BaseLoopStmt innermostEnclosingLoop(Raw::AdaNode n) {
  result = enclosingLoop(n) and
  not exists(Raw::BaseLoopStmt inner |
    inner = enclosingLoop(n) and result = inner.getParent+()
  )
}

/** Gets the loop targeted by `exit` statement `e`. */
Raw::BaseLoopStmt exitTargetLoop(Raw::ExitStmt e) {
  // named exit → the enclosing loop whose name matches
  result = enclosingLoop(e) and loopDeclName(result) = nameText(e.getLoopName())
  or
  // nameless exit → the innermost enclosing loop
  not exists(e.getLoopName()) and result = innermostEnclosingLoop(e)
}

/** Gets the label targeted by `goto` statement `g` (same scope, matching name). */
Raw::Label gotoTargetLabel(Raw::GotoStmt g) {
  nameText(result.getDecl().getName().getName()) = nameText(g.getLabelName()) and
  getEnclosingCfgScope(result) = getEnclosingCfgScope(g)
}
