/**
 * Ada instantiation of the shared `codeql.controlflow.ControlFlowGraph` library
 * (D-029; see `docs/cfg-design.md` and `docs/cfg-migration-plan.md`).
 *
 * It maps the Libadalang AST onto the library's AST signature (`Ast`) and gives the Ada
 * constructs the library does not know (`if … elsif`, plain `loop`, `exit when`,
 * `select`, calls that may raise) their steps in `Input`, the way CodeQL for Java does
 * for Kotlin's `when`.
 *
 * The library gives every AST node a node of its own, and "before" and "after" nodes
 * where it needs them; `getChild` says which children are evaluated, in which order,
 * and through which abrupt completions propagate. A `finally` part is not split: when
 * it completes, control may continue every way it was entered. Queries that need to
 * tell those ways apart use `ControlFlowReachability`.
 */

private import codeql.controlflow.ControlFlowGraph
private import codeql.controlflow.SuccessorType
private import codeql.util.Unit
private import codeql.ada.ast.internal.Raw

private module Cfg0 = Make0<Raw::Location, Ast>;

private module Cfg1 = Cfg0::Make1<Input>;

private module Cfg2 = Cfg1::Make2<Input>;

private import Cfg0
private import Cfg1
private import Cfg2
import Public

/** A body with executable content: a subprogram, expression function, task, entry or package body. Each has its own graph. */
class CfgScope extends Raw::AdaNode {
  CfgScope() {
    this instanceof Raw::SubpBody or
    this instanceof Raw::ExprFunction or
    this instanceof Raw::TaskBody or
    this instanceof Raw::EntryBody or
    this instanceof Raw::PackageBody
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
 * Gets the initializer evaluated when elaborating the `i`th declaration of `part`:
 * only object declarations are elaborated (a named number is static; the declarative
 * parts of nested packages are a documented gap, see `docs/cfg-design.md`).
 */
private Raw::Expr elaboratedInitializer(Raw::DeclarativePart part, int i) {
  result = part.getDecls().getChild(i).(Raw::ObjectDecl).getDefaultExpr()
}

/**
 * Gets the `index`th part of the body of `c`: the default values of its formals (see
 * `formalDefault`), an entry body's barrier, the initializers of its object
 * declarations in order, then its statements.
 */
private Raw::AdaNode bodyPart(CfgScope c, int index) {
  result = formalDefault(c, index)
  or
  index = 1000 and result = c.(Raw::EntryBody).getBarrier()
  or
  exists(int i | result = elaboratedInitializer(bodyDecls(c), i) and index = 2000 + i)
  or
  index = 1000000 and result = bodyStmts(c)
}

/** Holds if `hs` has exception handlers or a GNAT `finally` part. */
private predicate isTry(Raw::HandledStmts hs) {
  exists(hs.getExceptions().getChild(_)) or exists(hs.getFinallyPart())
}

/** Gets the `i`th exception handler of `hs`, pragmas among them skipped. */
private Raw::ExceptionHandler handler(Raw::HandledStmts hs, int i) {
  result =
    rank[i + 1](Raw::ExceptionHandler h, int j | h = hs.getExceptions().getChild(j) | h order by j)
}

/**
 * Holds if `n` is an expression, or a part of one, that is evaluated: as
 * a value is computed from.
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

/** Holds if evaluating `n` may raise (`mayRaiseAny`), other than by `raise`. */
private predicate mayRaise(Raw::AdaNode n) {
  mayRaiseAny(n) and
  not n instanceof Raw::RaiseStmt and
  not n instanceof Raw::RaiseExpr
}

/** Gets the `i`th branch of `select` statement `s`: an alternative, the `else` or abortable part. */
private Raw::StmtList selectBranch(Raw::SelectStmt s, int i) {
  result = s.getGuards().getChild(i).(Raw::SelectWhenPart).getStmts()
  or
  i = 1000 and result = s.getElsePart().getStmts()
  or
  i = 1001 and result = s.getThenAbortPart().getStmts()
}

/**
 * Gets the `index`th evaluated child of `n`: what is evaluated when `n` is, in order,
 * and what an abrupt completion propagates out of.
 */
private Raw::AdaNode getChild0(Raw::AdaNode n, int index) {
  // statements
  result = n.(Raw::StmtList).getChild(index) and
  (result instanceof Raw::Stmt or result instanceof Raw::PragmaNode)
  or
  exists(Raw::HandledStmts hs | hs = n |
    index = 0 and result = hs.getStmts()
    or
    result = handler(hs, index - 1)
    or
    index = 100000 and result = hs.getFinallyPart().getStmts()
  )
  or
  index = 0 and result = n.(Raw::ExceptionHandler).getStmts()
  or
  exists(Raw::AssignStmt s | s = n |
    index = 0 and result = s.getExpr()
    or
    index = 1 and result = s.getDest()
  )
  or
  index = 0 and result = n.(Raw::CallStmt).getCall()
  or
  index = 0 and result = n.(Raw::ReturnStmt).getReturnExpr()
  or
  exists(Raw::AdaNode r | r = n and (r instanceof Raw::RaiseStmt or r instanceof Raw::RaiseExpr) |
    index = 0 and result = [r.(Raw::RaiseStmt).getExceptionName(), r.(Raw::RaiseExpr).getExceptionName()]
    or
    index = 1 and result = [r.(Raw::RaiseStmt).getErrorMessage(), r.(Raw::RaiseExpr).getErrorMessage()]
  )
  or
  exists(Raw::IfStmt s | s = n |
    index = 0 and result = s.getCondExpr()
    or
    index = 1 and result = s.getThenStmts()
    or
    result = s.getAlternatives().getChild(index - 2)
    or
    index = 1000 and result = s.getElsePart().getStmts()
  )
  or
  exists(Raw::ElsifStmtPart p | p = n |
    index = 0 and result = p.getCondExpr()
    or
    index = 1 and result = p.getStmts()
  )
  or
  exists(Raw::CaseStmt s | s = n |
    index = 0 and result = s.getExpr()
    or
    result = s.getAlternatives().getChild(index - 1)
  )
  or
  // a `case` alternative's choices are its pattern (see `Ast::Case`)
  exists(Raw::CaseStmtAlternative a | a = n |
    index = 0 and result = a.getChoices()
    or
    index = 1000 and result = a.getStmts()
  )
  or
  index = 0 and result = n.(Raw::LoopStmt).getStmts()
  or
  exists(Raw::WhileLoopStmt s | s = n |
    index = 0 and result = s.getSpec().(Raw::WhileLoopSpec).getExpr()
    or
    index = 1 and result = s.getStmts()
  )
  or
  exists(Raw::ForLoopStmt s, Raw::ForLoopSpec spec | s = n and spec = s.getSpec() |
    index = 0 and result = spec.getIterExpr()
    or
    index = 1 and result = spec.getVarDecl().getId()
    or
    index = 2 and result = s.getStmts()
  )
  or
  index = 0 and
  n = any(Raw::ForLoopSpec s).getIterExpr() and
  result = n.(Raw::SubtypeIndication).getConstraint().(Raw::RangeConstraint).getRange().getRange()
  or
  index = 0 and result = n.(Raw::NamedStmt).getStmt()
  or
  index = 0 and result = n.(Raw::ExitStmt).getCondExpr()
  or
  index = 0 and result = n.(Raw::BeginBlock).getStmts()
  or
  exists(Raw::DeclBlock b | b = n |
    result = elaboratedInitializer(b.getDecls(), index)
    or
    index = 1000000 and result = b.getStmts()
  )
  or
  exists(Raw::ExtendedReturnStmt s | s = n |
    index = 0 and result = s.getDecl().getDefaultExpr()
    or
    index = 1 and result = s.getStmts()
  )
  or
  index = 0 and result = n.(Raw::AcceptStmtWithStmts).getStmts()
  or
  result = selectBranch(n, index)
  or
  // expressions
  exists(Raw::CallExpr call | call = n |
    index = 0 and result = call.getName()
    or
    index = 1 and result = call.getSuffix()
  )
  or
  exists(Raw::QuantifiedExpr q | q = n |
    index = 0 and result = q.getLoopSpec().getIterExpr()
    or
    index = 1 and result = q.getExpr()
  )
  or
  exists(Raw::IfExpr e | e = n |
    index = 0 and result = e.getCondExpr()
    or
    index = 1 and result = e.getThenExpr()
    or
    result = e.getAlternatives().getChild(index - 2)
    or
    index = 1000 and result = e.getElseExpr()
  )
  or
  exists(Raw::ElsifExprPart p | p = n |
    index = 0 and result = p.getCondExpr()
    or
    index = 1 and result = p.getThenExpr()
  )
  or
  exists(Raw::CaseExpr e | e = n |
    index = 0 and result = e.getExpr()
    or
    result = e.getCases().getChild(index - 1)
  )
  or
  exists(Raw::CaseExprAlternative a | a = n |
    index = 0 and result = a.getChoices()
    or
    index = 1000 and result = a.getExpr()
  )
  or
  // any other expression: its evaluated children, left to right
  exprLike(n) and
  not n instanceof Raw::CallExpr and
  not n instanceof Raw::QuantifiedExpr and
  not n instanceof Raw::IfExpr and
  not n instanceof Raw::CaseExpr and
  not n instanceof Raw::RaiseExpr and
  // a defining name (a `for` loop's variable) is a leaf
  not n instanceof Raw::DefiningName and
  result = n.getChild(index) and
  exprLike(result)
}

/** Holds if `n` is evaluated in callable `c`: reachable through `getChild0` from a body part. */
private predicate inCallable(Raw::AdaNode n, CfgScope c) {
  n = bodyPart(c, _)
  or
  n = c.(Raw::ExprFunction).getExpr()
  or
  exists(Raw::AdaNode parent | inCallable(parent, c) and n = getChild0(parent, _))
}

/** Provides an implementation of the AST signature for Ada. */
private module Ast implements AstSig<Raw::Location> {
  class AstNode = Raw::AdaNode;

  AstNode getChild(AstNode n, int index) { result = getChild0(n, index) and inCallable(n, _) }

  Callable getEnclosingCallable(AstNode node) { inCallable(node, result) }

  class Callable = CfgScope;

  AstNode callableGetBody(Callable c) { result = c.(Raw::ExprFunction).getExpr() }

  /** Formals are not in the graph: their defaults are body parts (`bodyPart`). */
  class Parameter extends AstNode {
    Parameter() { none() }

    Expr getDefaultValue() { none() }
  }

  Parameter callableGetParameter(Callable c, int i) { none() }

  class Stmt extends AstNode {
    Stmt() {
      this instanceof Raw::Stmt or
      this instanceof Raw::StmtList or
      this instanceof Raw::HandledStmts or
      this.(Raw::PragmaNode).getParent() instanceof Raw::StmtList
    }
  }

  class Expr extends AstNode {
    Expr() {
      exprLike(this) or
      this = any(Raw::ForLoopSpec s).getIterExpr()
    }
  }

  class BlockStmt extends Stmt instanceof Raw::StmtList {
    Stmt getStmt(int n) { result = this.(Raw::StmtList).getChild(n) }

    Stmt getLastStmt() {
      result = this.(Raw::StmtList).getChild(max(int i | exists(this.(Raw::StmtList).getChild(i))))
    }
  }

  class ExprStmt extends Stmt {
    ExprStmt() { none() }

    Expr getExpr() { none() }
  }

  class IfStmt extends Stmt {
    IfStmt() { none() }

    Expr getCondition() { none() }

    Stmt getThen() { none() }

    Stmt getElse() { none() }
  }

  class LoopStmt extends Stmt instanceof Raw::BaseLoopStmt {
    Stmt getBody() { result = super.getStmts() }
  }

  class WhileStmt extends LoopStmt instanceof Raw::WhileLoopStmt {
    Expr getCondition() { result = super.getSpec().(Raw::WhileLoopSpec).getExpr() }
  }

  class DoStmt extends LoopStmt {
    DoStmt() { none() }

    Expr getCondition() { none() }
  }

  class ForStmt extends LoopStmt {
    ForStmt() { none() }

    AstNode getInit(int index) { none() }

    Expr getCondition() { none() }

    AstNode getUpdate(int index) { none() }
  }

  class ForeachStmt extends LoopStmt instanceof Raw::ForLoopStmt {
    Expr getVariable() { result = super.getSpec().(Raw::ForLoopSpec).getVarDecl().getId() }

    Expr getCollection() { result = super.getSpec().(Raw::ForLoopSpec).getIterExpr() }
  }

  /** An unconditional `exit`; `exit when` has its own steps (`Input::step`). */
  class BreakStmt extends Stmt instanceof Raw::ExitStmt {
    BreakStmt() { not exists(super.getCondExpr()) }
  }

  class ContinueStmt extends Stmt {
    ContinueStmt() { none() }
  }

  class GotoStmt extends Stmt instanceof Raw::GotoStmt { }

  class ReturnStmt extends Stmt {
    ReturnStmt() { this instanceof Raw::ReturnStmt or this instanceof Raw::ExtendedReturnStmt }

    /** Gets the returned expression; an extended return evaluates its parts as children. */
    Expr getExpr() { result = this.(Raw::ReturnStmt).getReturnExpr() }
  }

  class Throw extends AstNode {
    Throw() { this instanceof Raw::RaiseStmt or this instanceof Raw::RaiseExpr }

    Expr getExpr() {
      result = this.(Raw::RaiseStmt).getExceptionName() or
      result = this.(Raw::RaiseExpr).getExceptionName()
    }
  }

  class TryStmt extends Stmt instanceof Raw::HandledStmts {
    TryStmt() { isTry(this) }

    Stmt getBody() { result = super.getStmts() }

    CatchClause getCatch(int index) { result = handler(this, index) }

    Stmt getFinally() { result = super.getFinallyPart().getStmts() }
  }

  class CatchClause extends AstNode instanceof Raw::ExceptionHandler {
    /** The choice parameter (`when E : others =>`) is not evaluated. */
    AstNode getVariable() { none() }

    Expr getCondition() { none() }

    Stmt getBody() { result = super.getStmts() }
  }

  class Switch extends AstNode {
    Switch() { this instanceof Raw::CaseStmt or this instanceof Raw::CaseExpr }

    Expr getExpr() {
      result = this.(Raw::CaseStmt).getExpr() or
      result = this.(Raw::CaseExpr).getExpr()
    }

    Case getCase(int index) {
      result = this.(Raw::CaseStmt).getAlternatives().getChild(index) or
      result = this.(Raw::CaseExpr).getCases().getChild(index)
    }

    Stmt getStmt(int index) { none() }
  }

  class Case extends AstNode {
    Case() { this instanceof Raw::CaseStmtAlternative or this instanceof Raw::CaseExprAlternative }

    /**
     * Gets the pattern of this alternative: its whole list of choices
     * (`Raw::AlternativesList`, `when A | B .. C =>`), matched at once. Ada choices
     * are static and are not evaluated one by one, so the list is a leaf that matches
     * or not, and cannot raise; the alternative then has a single match edge, which
     * dominates its body (as the Guards library needs).
     */
    AstNode getPattern(int index) {
      index = 0 and
      (
        result = this.(Raw::CaseStmtAlternative).getChoices() or
        result = this.(Raw::CaseExprAlternative).getChoices()
      )
    }

    Expr getGuard() { none() }

    AstNode getBody() {
      result = this.(Raw::CaseStmtAlternative).getStmts() or
      result = this.(Raw::CaseExprAlternative).getExpr()
    }
  }

  /** A `when others =>` alternative. */
  class DefaultCase extends Case {
    DefaultCase() { this.getPattern(0).getChild(_) instanceof Raw::OthersDesignator }
  }

  class ConditionalExpr extends Expr {
    ConditionalExpr() { none() }

    Expr getCondition() { none() }

    Expr getThen() { none() }

    Expr getElse() { none() }
  }

  class BinaryExpr extends Expr instanceof Raw::BinOp {
    Expr getLeftOperand() { result = super.getLeft() }

    Expr getRightOperand() { result = super.getRight() }
  }

  class LogicalAndExpr extends BinaryExpr {
    LogicalAndExpr() { this.(Raw::BinOp).getOp() instanceof Raw::OpAndThen }
  }

  class LogicalOrExpr extends BinaryExpr {
    LogicalOrExpr() { this.(Raw::BinOp).getOp() instanceof Raw::OpOrElse }
  }

  class NullCoalescingExpr extends BinaryExpr {
    NullCoalescingExpr() { none() }
  }

  class UnaryExpr extends Expr instanceof Raw::UnOp {
    Expr getOperand() { result = super.getExpr() }
  }

  /**
   * Not used: the library only gives `not` steps in a conditional context, and an Ada
   * `not` is also an ordinary (Boolean or modular) operator elsewhere.
   */
  class LogicalNotExpr extends UnaryExpr {
    LogicalNotExpr() { none() }
  }

  /** Ada's `:=` is a statement, not an expression: `AssignStmt` is ordinary (`getChild0`). */
  class Assignment extends BinaryExpr {
    Assignment() { none() }
  }

  class AssignExpr extends Assignment { }

  class CompoundAssignment extends Assignment { }

  class AssignLogicalAndExpr extends CompoundAssignment { }

  class AssignLogicalOrExpr extends CompoundAssignment { }

  class AssignNullCoalescingExpr extends CompoundAssignment { }

  class BooleanLiteral extends Expr {
    BooleanLiteral() { none() }

    boolean getValue() { none() }
  }

  class PatternMatchExpr extends Expr {
    PatternMatchExpr() { none() }

    Expr getExpr() { none() }

    AstNode getPattern() { none() }
  }
}

private module Input implements InputSig1, InputSig2 {
  predicate cfgCachedStageRef() { CfgCachedStage::ref() }

  private newtype TLabel =
    /** The target of an `exit`: a loop. */
    TLoopLabel(Raw::BaseLoopStmt loop) { loop = exitTargetLoop(_) } or
    /** The target of a `goto`: a statement label (`<<L>>`). */
    TStmtLabel(Raw::Label l) { l = gotoTargetLabel(_) }

  /**
   * A jump target. An `exit` names the loop it leaves and a `goto` the label it goes
   * to, resolved (`exitTargetLoop`, `gotoTargetLabel`), so that no other
   * construct catches the jump on the way: an unlabelled `exit` in a `case`
   * alternative leaves the loop, not the `case`.
   */
  class Label extends TLabel {
    string toString() {
      exists(Raw::BaseLoopStmt loop | this = TLoopLabel(loop) | result = "loop@" + loop.getLocation().getStartLine())
      or
      exists(Raw::Label l | this = TStmtLabel(l) | result = l.toString())
    }
  }

  predicate hasLabel(Ast::AstNode n, Label l) {
    l = TLoopLabel(n) or
    l = TLoopLabel(exitTargetLoop(n)) or
    l = TStmtLabel(n) or
    l = TStmtLabel(gotoTargetLabel(n))
  }

  class CallableContext = Unit;

  Ast::AstNode callableGetBodyPart(Ast::Callable c, CallableContext ctx, int index) {
    exists(ctx) and result = bodyPart(c, index)
  }

  /** A handler with `others` among its choices catches everything. */
  predicate catchAll(Ast::CatchClause catch) {
    catch.(Raw::ExceptionHandler).getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator
  }

  /** Ada's `case` covers every value, so its last alternative matches what is left. */
  predicate matchAll(Ast::Case c) {
    c instanceof Ast::DefaultCase
    or
    exists(Ast::Switch s, int last |
      s.getCase(last) = c and not exists(s.getCase(last + 1))
    )
  }

  private Raw::Expr guardCond(Raw::AdaNode n, int i) {
    i = 0 and result = [n.(Raw::IfStmt).getCondExpr(), n.(Raw::IfExpr).getCondExpr()]
    or
    result = n.(Raw::IfStmt).getAlternatives().getChild(i - 1).(Raw::ElsifStmtPart).getCondExpr()
    or
    result = n.(Raw::IfExpr).getAlternatives().getChild(i - 1).(Raw::ElsifExprPart).getCondExpr()
  }

  /** Gets what runs when guard `i` of `if` statement or expression `n` is true. */
  private Raw::AdaNode guardThen(Raw::AdaNode n, int i) {
    i = 0 and result = [n.(Raw::IfStmt).getThenStmts().(Raw::AdaNode), n.(Raw::IfExpr).getThenExpr()]
    or
    result = n.(Raw::IfStmt).getAlternatives().getChild(i - 1).(Raw::ElsifStmtPart).getStmts()
    or
    result = n.(Raw::IfExpr).getAlternatives().getChild(i - 1).(Raw::ElsifExprPart).getThenExpr()
  }

  /** Gets the guarded part (`elsif`) that holds guard `i` of `n`, if `i > 0`. */
  private Raw::AdaNode guardPart(Raw::AdaNode n, int i) {
    result = [n.(Raw::IfStmt).getAlternatives().getChild(i - 1), n.(Raw::IfExpr).getAlternatives().getChild(i - 1)]
  }

  private Raw::AdaNode elseOf(Raw::AdaNode n) {
    result = [n.(Raw::IfStmt).getElsePart().getStmts().(Raw::AdaNode), n.(Raw::IfExpr).getElseExpr()]
  }

  predicate inConditionalContext(Ast::AstNode n, ConditionKind kind) {
    kind.isBoolean() and
    (
      n = guardCond(_, _) or
      n = any(Raw::ExitStmt e).getCondExpr()
    )
  }

  predicate preOrderExpr(Ast::Expr e) { e instanceof Raw::IfExpr }

  /** The branches of an `if` expression give it their value. */
  predicate propagatesValue(Ast::AstNode child, Ast::AstNode parent) {
    parent instanceof Raw::IfExpr and (child = guardThen(parent, _) or child = elseOf(parent))
  }

  /**
   * Statements whose node follows their parts: an assignment (data flow writes its
   * target there), a call statement (where the call has happened), `exit when` (where
   * the jump is taken), and calls written without parentheses, which may raise.
   */
  predicate postOrInOrder(Ast::AstNode n) {
    n instanceof Raw::AssignStmt or
    n instanceof Raw::CallStmt or
    exists(n.(Raw::ExitStmt).getCondExpr()) or
    mayRaise(n)
  }

  predicate beginAbruptCompletion(
    Ast::AstNode ast, PreControlFlowNode n, AbruptCompletion c, boolean always
  ) {
    // a call may raise; one to a `No_Return` subprogram can only raise
    mayRaise(ast) and
    n.isIn(ast) and
    c.asSimpleAbruptCompletion() instanceof ExceptionSuccessor and
    if callsNoReturn(ast) then always = true else always = false
    or
    // `exit when C`, taken
    exists(Raw::ExitStmt e | e = ast and exists(e.getCondExpr()) |
      n.isIn(e) and
      c.getSuccessorType() instanceof BreakSuccessor and
      c.hasLabel(TLoopLabel(exitTargetLoop(e))) and
      always = true
    )
  }

  predicate endAbruptCompletion(Ast::AstNode ast, PreControlFlowNode n, AbruptCompletion c) {
    none()
  }

  predicate step(PreControlFlowNode n1, PreControlFlowNode n2) {
    // `if` statements and expressions: guard by guard (as Java's `when`)
    exists(Raw::AdaNode s | exists(guardCond(s, 0)) |
      n1.isBefore(s) and n2.isBefore(guardCond(s, 0))
      or
      exists(int i | exists(guardCond(s, i)) |
        n1.isBefore(guardPart(s, i)) and n2.isBefore(guardCond(s, i))
        or
        n1.isAfterTrue(guardCond(s, i)) and n2.isBefore(guardThen(s, i))
        or
        n1.isAfterFalse(guardCond(s, i)) and
        (
          n2.isBefore(guardPart(s, i + 1))
          or
          not exists(guardCond(s, i + 1)) and n2.isBefore(elseOf(s))
          or
          not exists(guardCond(s, i + 1)) and
          not exists(elseOf(s)) and
          // `(if C then E)` is `True` when `C` is false
          n2.isAfterValue(s, any(BooleanSuccessor b | b.getValue() = true))
        )
        or
        s instanceof Raw::IfStmt and n1.isAfter(guardThen(s, i)) and n2.isAfter(s)
      )
      or
      s instanceof Raw::IfStmt and n1.isAfter(elseOf(s)) and n2.isAfter(s)
    )
    or
    // a plain `loop … end loop`, which only an `exit`, `return`, raise or `goto` leaves
    exists(Raw::LoopStmt loop |
      n1.isBefore(loop) and n2.isAdditional(loop, "[LoopHeader]")
      or
      n1.isAdditional(loop, "[LoopHeader]") and n2.isBefore(loop.getStmts())
      or
      n1.isAfter(loop.getStmts()) and n2.isAdditional(loop, "[LoopHeader]")
    )
    or
    // `exit when C`
    exists(Raw::ExitStmt e, Raw::Expr cond | cond = e.getCondExpr() |
      n1.isBefore(e) and n2.isBefore(cond)
      or
      n1.isAfterTrue(cond) and n2.isIn(e)
      or
      n1.isAfterFalse(cond) and n2.isAfter(e)
    )
    or
    // `select`: any one of its alternatives (D-013: the rendezvous is not modelled),
    // chosen alternative by alternative: `[select i]` takes the `i`th, `[skip i]` one
    // of those after it. The choice is not a condition anyone wrote; it is spelt with
    // Boolean successors only because a node may not have two plain ones.
    exists(Raw::SelectStmt s |
      n1.isBefore(s) and not exists(selectBranch(s, _)) and n2.isAfter(s)
      or
      n1.isBefore(s) and
      not exists(rankedSelectBranch(s, 2)) and
      n2.isBefore(rankedSelectBranch(s, 1))
      or
      n1.isBefore(s) and exists(rankedSelectBranch(s, 2)) and n2.isAdditional(s, selectTag(1, [true, false]))
      or
      exists(int i, boolean take | n1.isAdditional(s, selectTag(i, take)) |
        take = true and n2.isBefore(rankedSelectBranch(s, i))
        or
        take = false and
        (
          if exists(rankedSelectBranch(s, i + 2))
          then n2.isAdditional(s, selectTag(i + 1, [true, false]))
          else n2.isBefore(rankedSelectBranch(s, i + 1))
        )
      )
      or
      n1.isAfter(selectBranch(s, _)) and n2.isAfter(s)
    )
  }

  /** Gets the `i`th (from 1) branch of `select` statement `s`. */
  private Raw::StmtList rankedSelectBranch(Raw::SelectStmt s, int i) {
    result = rank[i](Raw::StmtList b, int j | b = selectBranch(s, j) | b order by j)
  }

  /** Gets the tag of the node that takes (`take`) or skips the `i`th branch of a `select`. */
  bindingset[i, take]
  private string selectTag(int i, boolean take) {
    take = true and result = "[select " + i + "]"
    or
    take = false and result = "[skip " + i + "]"
  }

  predicate additionalNode(Ast::AstNode n, string tag, NormalSuccessor t) {
    exists(int i, boolean take |
      exists(rankedSelectBranch(n, i + 1)) and
      take = [true, false] and
      tag = selectTag(i, take) and
      t.(BooleanSuccessor).getValue() = take
    )
  }
}

/**
 * Gets the innermost body that encloses `n` in the source. For a node in the graph this
 * is its node's `getEnclosingCallable()`; it is also defined for declarations, which
 * are not.
 */
CfgScope getEnclosingCfgScope(Raw::AdaNode n) { result = syntacticScope(n) }

/** A control-flow node that branches on a Boolean condition. */
class ConditionNode extends ControlFlowNode {
  ConditionNode() { exists(this.getASuccessor(any(BooleanSuccessor t))) }

  /** Gets a successor taken when the condition is `branch`. */
  ControlFlowNode getABranchSuccessor(boolean branch) {
    result = this.getASuccessor(any(BooleanSuccessor t | t.getValue() = branch))
  }
}

// ---------------------------------------------------------------------------
// AST facts the graph is built from: calls that may raise, jump targets, formal
// defaults. Labels and loop names are matched textually within the same scope.
// ---------------------------------------------------------------------------

/** Holds if `op` is a short-circuit operator (`and then` / `or else`). */
predicate isShortCircuitOp(Raw::Op op) { op instanceof Raw::OpAndThen or op instanceof Raw::OpOrElse }

/**
 * Holds if evaluating `n` may raise an exception (conservative, D-013): a `raise`, or
 * a call.
 */
private predicate mayRaiseAny(Raw::AdaNode n) {
  n instanceof Raw::RaiseStmt or
  n instanceof Raw::RaiseExpr or
  n instanceof Raw::CallStmt or
  n instanceof Raw::CallExpr or
  isParenthesislessCall(n)
}

/**
 * Holds if `n` is a call written without parentheses inside an expression
 * (`return Id.P_Referenced_Decl;`, `X := Get;`): a name that resolves to a
 * subprogram and is the whole callee, not part of a larger name. Like any call it
 * may raise. A `CallStmt`'s bare call is already covered by the statement. A name
 * that does not resolve cannot be told apart from an object and is left out
 * (Task 9.6, limitation I).
 */
private predicate isParenthesislessCall(Raw::AdaNode n) {
  (n instanceof Raw::Identifier or n instanceof Raw::DottedName) and
  exists(Raw::BasicDecl d | ada_xref(n, d) |
    d instanceof Raw::ClassicSubpDecl or
    d instanceof Raw::BaseSubpBody or
    d instanceof Raw::SubpBodyStub
  ) and
  not n = any(Raw::CallExpr c).getName() and
  not n = any(Raw::CallStmt s).getCall() and
  not n = any(Raw::DottedName dn).getSuffix() and
  not n = any(Raw::AttributeRef a).getPrefix() and
  not n.getParent+() instanceof Raw::EndName and
  not n.getParent() instanceof Raw::DefiningName and
  // the prefix of an expanded name naming an enclosing subprogram (`Outer.X`)
  not exists(Raw::DottedName dn, Raw::BasicDecl d |
    n = dn.getPrefix() and ada_xref(n, d) and n.getParent+() = d
  )
}

/**
 * Holds if `d` is a `No_Return` subprogram. The mark is usually on the spec, while a
 * call inside the package body may resolve to the body, so a body counts when the
 * declaration it completes (`ada_body_part`) is marked.
 */
private predicate isNoReturnSubprogram(Raw::BasicDecl d) {
  d.hasNoReturnMark()
  or
  exists(Raw::BasicDecl spec | ada_body_part(spec, d) and spec.hasNoReturnMark())
}

/**
 * Holds if `n` is a call to a `No_Return` subprogram: a `CallExpr`, or a `CallStmt`
 * (whose call may be a bare name, `Fail;`). Such a call never completes normally,
 * only by raising (Task 9.6, defect D).
 */
predicate callsNoReturn(Raw::AdaNode n) {
  exists(Raw::Name callee, Raw::BasicDecl d |
    callee = n.(Raw::CallExpr).getName()
    or
    callee = n.(Raw::CallStmt).getCall() and not callee instanceof Raw::CallExpr
    or
    callee = n.(Raw::CallStmt).getCall().(Raw::CallExpr).getName()
  |
    ada_xref(callee, d) and isNoReturnSubprogram(d)
  )
}

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
  not exists(Raw::BaseLoopStmt inner | inner = enclosingLoop(n) and result = inner.getParent+())
}

/** Gets the loop targeted by `exit` statement `e`. */
Raw::BaseLoopStmt exitTargetLoop(Raw::ExitStmt e) {
  // named exit → the enclosing loop whose name matches
  result = enclosingLoop(e) and loopDeclName(result) = nameText(e.getLoopName())
  or
  // nameless exit → the innermost enclosing loop
  not exists(e.getLoopName()) and result = innermostEnclosingLoop(e)
}

/** Gets the innermost body that syntactically encloses `n`. */
private CfgScope syntacticScope(Raw::AdaNode n) {
  result = n.getParent+() and
  not exists(CfgScope closer | closer = n.getParent+() and result = closer.getParent+())
}

/** Gets the label targeted by `goto` statement `g` (same scope, matching name). */
Raw::Label gotoTargetLabel(Raw::GotoStmt g) {
  nameText(result.getDecl().getName().getName()) = nameText(g.getLabelName()) and
  syntacticScope(result) = syntacticScope(g)
}

/**
 * Gets the default value of the `k`th formal (0-based, across `ParamSpec` groups by
 * group) of subprogram body `body` that has one, or none. Ada requires a body to
 * repeat its spec's defaults (full conformance), so the body's own formals carry them.
 * Ada evaluates a default at each call that omits the actual; evaluating it once at
 * entry is the callee-side approximation, and its value then reaches the formal on
 * every call (Task 9.6).
 */
Raw::Expr formalDefault(Raw::SubpBody body, int k) {
  result =
    rank[k + 1](Raw::ParamSpec ps, Raw::Expr d |
      ps = body.getSubpSpec().getSubpParams().getParams().getChild(_) and
      d = ps.getDefaultExpr()
    |
      d order by ps.getParentIndex()
    )
}
