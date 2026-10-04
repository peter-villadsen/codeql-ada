/**
 * Provides the control-flow *completions* for the Ada CFG.
 *
 * A completion models how a statement or expression finishes, and thereby
 * which edge label (`SuccessorType`) leaves the corresponding CFG node. This
 * is the Ada instantiation of the completion contract required by the shared
 * `codeql/controlflow` framework (see `docs/cfg-design.md` for the full table).
 *
 * Completions modelled: `SimpleCompletion` (fall-through), `BooleanCompletion`
 * (true/false out of a condition), `ReturnCompletion`, `RaiseCompletion`,
 * `ExitCompletion` (loop `exit`), and `GotoCompletion` (`goto`). Short-circuit
 * boolean contexts and conditional expressions extend `isBooleanContext` in
 * task 7.4.
 */

private import codeql.controlflow.SuccessorType
private import codeql.util.Boolean
private import codeql.ada.ast.internal.Raw

newtype TCompletion =
  TNormalCompletion() or
  TBooleanCompletion(Boolean b) or
  TReturnCompletion() or
  TRaiseCompletion() or
  TExitCompletion() or
  TGotoCompletion()

/** A completion of a statement or an expression. */
abstract class Completion extends TCompletion {
  /** Gets a textual representation of this completion. */
  abstract string toString();

  /** Gets a successor type that matches this completion. */
  abstract SuccessorType getAMatchingSuccessorType();

  /**
   * Holds if this is a *specific* completion for `n`, that is, one that
   * replaces the default normal completion. Additive completions such as
   * `RaiseCompletion` on a call — which may *also* complete normally — are not
   * specific.
   */
  predicate isValidForSpecific(Raw::AdaNode n) { none() }

  /** Holds if this completion is a valid way for `n` to finish. */
  predicate isValidFor(Raw::AdaNode n) { this.isValidForSpecific(n) }
}

/** A completion that represents non-abrupt evaluation. */
abstract class NormalCompletion extends Completion { }

/**
 * The simple (default) normal completion: `n` finished normally and control
 * falls through to its successor.
 */
class SimpleCompletion extends NormalCompletion, TNormalCompletion {
  override string toString() { result = "normal" }

  override DirectSuccessor getAMatchingSuccessorType() { any() }

  // Default completion: valid wherever no completion is specifically required
  // (the node falls through). Diverging statements and condition nodes (which
  // complete with a `BooleanCompletion`) are excluded.
  override predicate isValidFor(Raw::AdaNode n) { not diverges(n) and not isBooleanContext(n) }
}

/**
 * A completion whose Boolean value determines the successor: the two outgoing
 * edges of a condition node. Unsplit — every condition emits both `true` and
 * `false` (see `docs/cfg-design.md`).
 */
class BooleanCompletion extends NormalCompletion, TBooleanCompletion {
  /** Gets the Boolean value of this completion. */
  boolean getValue() { this = TBooleanCompletion(result) }

  override string toString() { result = this.getValue().toString() }

  override BooleanSuccessor getAMatchingSuccessorType() { result.getValue() = this.getValue() }

  override predicate isValidFor(Raw::AdaNode n) { isBooleanContext(n) }
}

/** The completion of a `return` statement. */
class ReturnCompletion extends Completion, TReturnCompletion {
  override string toString() { result = "return" }

  override ReturnSuccessor getAMatchingSuccessorType() { any() }

  override predicate isValidForSpecific(Raw::AdaNode n) { n instanceof Raw::ReturnStmt }
}

/**
 * The completion of a node that raises an exception. Emitted by `raise`
 * statements/expressions and — conservatively (D-013) — by every call. This is
 * *additive*: a call also completes `SimpleCompletion` on its normal path.
 */
class RaiseCompletion extends Completion, TRaiseCompletion {
  override string toString() { result = "raise" }

  override ExceptionSuccessor getAMatchingSuccessorType() { any() }

  override predicate isValidFor(Raw::AdaNode n) { mayRaise(n) }
}

/**
 * The completion of a loop `exit`: an intra-scope jump to the point after the
 * targeted loop. Realised as a direct successor edge from the `exit` node to
 * the loop node (see `ExitStmtTree`), so it is never produced via
 * `completionIsValidFor`.
 */
class ExitCompletion extends Completion, TExitCompletion {
  override string toString() { result = "exit" }

  override BreakSuccessor getAMatchingSuccessorType() { any() }
}

/**
 * The completion of a `goto`: an intra-scope jump to the target label. Realised
 * as a direct successor edge from the `goto` node to the label node (see
 * `GotoStmtTree`).
 */
class GotoCompletion extends Completion, TGotoCompletion {
  override string toString() { result = "goto" }

  override GotoSuccessor getAMatchingSuccessorType() { any() }
}

/**
 * Holds if `n` unconditionally diverges — never completes normally, so
 * `SimpleCompletion` is not valid for it. `exit`/`goto`/`return … do … end` are
 * handled by their own trees (which produce the completion explicitly) rather
 * than through this predicate.
 */
predicate diverges(Raw::AdaNode n) {
  n instanceof Raw::ReturnStmt or
  n instanceof Raw::RaiseStmt or
  n instanceof Raw::RaiseExpr or
  callsNoReturn(n)
}

/** Holds if `d` carries a `No_Return` aspect, or is named by a `pragma No_Return`. */
private predicate hasNoReturnMark(Raw::BasicDecl d) {
  exists(Raw::AspectAssoc a | a = d.getAspects().getAspectAssocs().getChild(_) |
    a.getId().(Raw::Identifier).getValue().toLowerCase() = "no_return" and
    not a.getExpr().(Raw::Identifier).getValue().toLowerCase() = "false"
  )
  or
  exists(Raw::PragmaNode p |
    p.getId().getValue().toLowerCase() = "no_return" and
    ada_xref(p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr(), d)
  )
}

/**
 * Holds if `d` is a `No_Return` subprogram. The mark is usually on the spec, while a
 * call inside the package body may resolve to the body, so a body counts when the
 * declaration it completes (`ada_body_part`) is marked.
 */
private predicate isNoReturnSubprogram(Raw::BasicDecl d) {
  hasNoReturnMark(d)
  or
  exists(Raw::BasicDecl spec | ada_body_part(spec, d) and hasNoReturnMark(spec))
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

/** Holds if `op` is a short-circuit operator (`and then` / `or else`). */
predicate isShortCircuitOp(Raw::Op op) {
  op instanceof Raw::OpAndThen or op instanceof Raw::OpOrElse
}

/** Holds if evaluating `n` may raise an exception (conservative, D-013). */
predicate mayRaise(Raw::AdaNode n) {
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
 * Holds if `n` is evaluated in a Boolean context — the controlling condition of
 * an `if`/`elsif`, a `while` loop, or an `exit when`. Such a node completes with
 * a `BooleanCompletion` rather than a `SimpleCompletion`. Extended in 7.4 with
 * short-circuit operands and conditional-expression conditions.
 */
predicate isBooleanContext(Raw::AdaNode n) {
  n = any(Raw::IfStmt s).getCondExpr() or
  n = any(Raw::ElsifStmtPart s).getCondExpr() or
  n = any(Raw::WhileLoopSpec s).getExpr() or
  n = any(Raw::ExitStmt s).getCondExpr() or
  n = any(Raw::IfExpr s).getCondExpr() or
  n = any(Raw::ElsifExprPart s).getCondExpr() or
  // the left operand of a short-circuit operator always drives a branch; its
  // Boolean value decides whether the right operand is evaluated
  exists(Raw::BinOp b | isShortCircuitOp(b.getOp()) and n = b.getLeft())
}

/** Holds if `c` represents normal (non-abrupt) evaluation. */
predicate completionIsNormal(Completion c) { c instanceof NormalCompletion }

/** Holds if `c` is the simple (default) normal completion. */
predicate completionIsSimple(Completion c) { c instanceof SimpleCompletion }

/** Holds if `c` is a valid completion for AST node `n`. */
predicate completionIsValidFor(Completion c, Raw::AdaNode n) { c.isValidFor(n) }
