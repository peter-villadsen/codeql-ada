/**
 * Provides classes and predicates for reasoning about guards and the control-flow
 * elements controlled by those guards.
 *
 * A `Guard` is an expression whose value decides which way control goes: an `if` or
 * `elsif` condition, a `while` or `exit when` condition, an operand of `and then` /
 * `or else`, or a `case` alternative (which as a guard is `true` when it matches).
 * `g.controls(bb, branch)` holds if basic block `bb` only runs when `g` evaluated to
 * `branch`, also through implications: `A and then B` being `true` means `A` was,
 * `X /= null` being `true` means `X` is not null, and an SSA variable assigned a
 * condition carries it (`OK := X > 0; if OK then` is guarded by `X > 0` too).
 *
 * This is the shared `codeql.controlflow.Guards` library over the Ada control-flow
 * graph and SSA (`codeql.ada.dataflow.Ssa`), as CodeQL for Java's is.
 *
 * ```ql
 * import ada
 * import codeql.ada.controlflow.Guards
 *
 * from Guard g, Expr e, BasicBlock bb
 * where g.isEquality(e, any(NullLiteral n), false) and g.controls(bb, true)
 * select bb, "Runs only when $@ is not null.", e, e.toString()
 * ```
 */

private import codeql.controlflow.Guards as SharedGuards
private import codeql.controlflow.SuccessorType
private import codeql.ada.ast.internal.Raw
private import ada
private import codeql.ada.dataflow.internal.SsaImpl as SsaImpl
private import ControlFlowGraph
private import internal.ControlFlowGraphImpl as CfgImpl

/** Holds if `n` names the enumeration literal `Standard.True` (`b = true`) or `Standard.False`. */
private predicate isBooleanLiteral(Raw::AdaNode n, boolean b) {
  exists(Raw::BasicDecl d | ada_xref(n, d) and d instanceof Raw::EnumLiteralDecl |
    d.(BasicDecl).hasQualifiedName("Standard.True") and b = true
    or
    d.(BasicDecl).hasQualifiedName("Standard.False") and b = false
  )
}

/** Gets the value of decimal integer literal `lit` (`1_000`), if it has no base or exponent. */
private int intLiteralValue(Raw::IntLiteral lit) {
  exists(string s | s = lit.getValue().replaceAll("_", "") |
    s.regexpMatch("[0-9]{1,9}") and result = s.toInt()
  )
}

/** Gets the enumeration literal, other than `True` or `False`, that `e` names. */
private Raw::EnumLiteralDecl enumLiteralOf(Raw::AdaNode e) {
  ada_xref(e, result) and not isBooleanLiteral(e, _)
}

private class ParameterAlias = Parameter;

final private class FinalSubprogram = Subprogram;

private module GuardsInput implements
  SharedGuards::InputSig<Raw::Location, CfgImpl::ControlFlowNode, CfgImpl::BasicBlock>
{
  class NormalExitNode = ControlFlow::NormalExitNode;

  class AstNode = Raw::AdaNode;

  class Expr = SsaImpl::SsaExpr;

  private newtype TConstantValue =
    TCharValue(string c) { c = any(Raw::CharLiteral lit).getValue() } or
    TStringValue(string s) { s = any(Raw::StringLiteral lit).getValue() } or
    TEnumValue(Raw::EnumLiteralDecl d) {
      not d.(BasicDecl).hasQualifiedName(["Standard.True", "Standard.False"])
    }

  class ConstantValue extends TConstantValue {
    string toString() {
      this = TCharValue(result)
      or
      this = TStringValue(result)
      or
      exists(Raw::EnumLiteralDecl d | this = TEnumValue(d) and result = d.toString())
    }
  }

  /** A literal: `null`, `True`/`False`, a decimal integer, a character, string or enumeration literal. */
  class ConstantExpr extends Expr {
    ConstantExpr() {
      this instanceof Raw::NullLiteral or
      isBooleanLiteral(this, _) or
      exists(intLiteralValue(this)) or
      this instanceof Raw::CharLiteral or
      this instanceof Raw::StringLiteral or
      exists(enumLiteralOf(this))
    }

    predicate isNull() { this instanceof Raw::NullLiteral }

    boolean asBooleanValue() { isBooleanLiteral(this, result) }

    int asIntegerValue() { result = intLiteralValue(this) }

    ConstantValue asConstantValue() {
      result = TCharValue(this.(Raw::CharLiteral).getValue())
      or
      result = TStringValue(this.(Raw::StringLiteral).getValue())
      or
      result = TEnumValue(enumLiteralOf(this))
    }
  }

  /** An expression that is never null: an allocator, or an `'Access` of an object. */
  class NonNullExpr extends Expr {
    NonNullExpr() {
      this instanceof Raw::Allocator
      or
      this.(Raw::AttributeRef).getAttribute().getValue().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access"]
    }
  }

  /**
   * A `case` alternative. Its choices are matched at once, at the node of their list,
   * which has a `match` and a `no-match` edge (`docs/cfg-design.md`); `when others`
   * matches whatever is left.
   */
  class Case extends AstNode {
    Case() { this instanceof Raw::CaseStmtAlternative or this instanceof Raw::CaseExprAlternative }

    private Raw::AlternativesList getChoices() {
      result = this.(Raw::CaseStmtAlternative).getChoices() or
      result = this.(Raw::CaseExprAlternative).getChoices()
    }

    private Raw::AdaNode getChoice(int i) { result = this.getChoices().getChild(i) }

    Expr getSwitchExpr() {
      result = this.getParent().getParent().(Raw::CaseStmt).getExpr()
      or
      result = this.getParent().getParent().(Raw::CaseExpr).getExpr()
    }

    predicate isDefaultCase() { this.getChoice(_) instanceof Raw::OthersDesignator }

    ConstantExpr asConstantCase() {
      result = this.getChoice(0) and not exists(this.getChoice(1))
    }

    private predicate choicesEdge(BasicBlock bb1, BasicBlock bb2, boolean match) {
      bb1.getLastNode().injects(this.getChoices()) and
      bb2 = bb1.getASuccessor(any(MatchingSuccessor s | s.getValue() = match))
    }

    predicate matchEdge(BasicBlock bb1, BasicBlock bb2) { this.choicesEdge(bb1, bb2, true) }

    predicate nonMatchEdge(BasicBlock bb1, BasicBlock bb2) { this.choicesEdge(bb1, bb2, false) }
  }

  /** `A and then B`, and `A and B` on Booleans. */
  class AndExpr extends Expr instanceof Raw::BinOp {
    AndExpr() { super.getOp() instanceof Raw::OpAndThen or super.getOp() instanceof Raw::OpAnd }

    Expr getAnOperand() { result = [super.getLeft(), super.getRight()] }
  }

  /** `A or else B`, and `A or B` on Booleans. */
  class OrExpr extends Expr instanceof Raw::BinOp {
    OrExpr() { super.getOp() instanceof Raw::OpOrElse or super.getOp() instanceof Raw::OpOr }

    Expr getAnOperand() { result = [super.getLeft(), super.getRight()] }
  }

  class NotExpr extends Expr instanceof Raw::UnOp {
    NotExpr() { super.getOp() instanceof Raw::OpNot }

    Expr getOperand() { result = super.getExpr() }
  }

  /** A parenthesised expression, whose value is its operand's. */
  class IdExpr extends Expr instanceof Raw::ParenExpr {
    Expr getEqualChildExpr() { result = super.getExpr() }
  }

  predicate equalityTest(Expr eqtest, Expr left, Expr right, boolean polarity) {
    exists(Raw::RelationOp r | r = eqtest |
      left = r.getLeft() and
      right = r.getRight() and
      (
        r.getOp() instanceof Raw::OpEq and polarity = true
        or
        r.getOp() instanceof Raw::OpNeq and polarity = false
      )
    )
  }

  /** `(if C then A else B)`, with no `elsif`. */
  class ConditionalExpr extends Expr instanceof Raw::IfExpr {
    ConditionalExpr() { not exists(super.getAlternatives().getChild(_)) and exists(super.getElseExpr()) }

    Expr getCondition() { result = super.getCondExpr() }

    Expr getThen() { result = super.getThenExpr() }

    Expr getElse() { result = super.getElseExpr() }
  }

  class Parameter = ParameterAlias;

  class ParameterPosition extends int {
    ParameterPosition() { this = any(Parameter p).getIndex() }
  }

  class ArgumentPosition extends int {
    ArgumentPosition() { this = any(Parameter p).getIndex() }
  }

  predicate parameterMatch(ParameterPosition ppos, ArgumentPosition apos) { ppos = apos }

  /** A function that nothing overrides, so that a call to it runs its body. */
  class NonOverridableMethod extends FinalSubprogram {
    NonOverridableMethod() { this.isFunction() and not exists(this.getAnOverride()) }

    Parameter getParameter(ParameterPosition ppos) { result = super.getParameter(ppos) }

    /** Gets an expression this function returns. */
    Expr getAReturnExpr() {
      exists(Raw::ReturnStmt r |
        r.getReturnExpr() = result and r.getEnclosingSubprogram() = this
      )
      or
      result = this.getADeclaration().(Raw::ExprFunction).getExpr()
    }
  }

  class NonOverridableMethodCall extends Expr instanceof Call {
    NonOverridableMethodCall() { super.getTarget() instanceof NonOverridableMethod }

    NonOverridableMethod getMethod() { result = super.getTarget() }

    Expr getArgument(ArgumentPosition apos) { result = super.getArgument(apos) }
  }
}

private module GuardsImpl = SharedGuards::Make<Raw::Location, CfgImpl::Cfg, GuardsInput>;

/**
 * Holds if `r` compares `e` with integer constant `k` (`e < k`, `k >= e`, …) so that
 * `r` being `true` ensures `e <= bound` (`upper = true`) or `e >= bound`.
 */
private predicate integerComparison(Raw::RelationOp r, Raw::Expr e, int bound, boolean upper) {
  exists(Raw::Op op, Raw::Expr other, int k, boolean eOnLeft |
    op = r.getOp() and
    k = intLiteralValue(other) and
    (
      e = r.getLeft() and other = r.getRight() and eOnLeft = true
      or
      e = r.getRight() and other = r.getLeft() and eOnLeft = false
    )
  |
    // e < k, e <= k, k > e, k >= e
    (
      op instanceof Raw::OpLt and eOnLeft = true or op instanceof Raw::OpGt and eOnLeft = false
    ) and
    bound = k - 1 and
    upper = true
    or
    (
      op instanceof Raw::OpLte and eOnLeft = true or op instanceof Raw::OpGte and eOnLeft = false
    ) and
    bound = k and
    upper = true
    or
    // e > k, e >= k, k < e, k <= e
    (
      op instanceof Raw::OpGt and eOnLeft = true or op instanceof Raw::OpLt and eOnLeft = false
    ) and
    bound = k + 1 and
    upper = false
    or
    (
      op instanceof Raw::OpGte and eOnLeft = true or op instanceof Raw::OpLte and eOnLeft = false
    ) and
    bound = k and
    upper = false
  )
}

private module LogicInput implements GuardsImpl::LogicInputSig {
  import SsaImpl::Ssa

  predicate rangeGuard(
    GuardsImpl::PreGuard guard, GuardsImpl::GuardValue val, GuardsInput::Expr e, int k,
    boolean upper
  ) {
    // `e < k` true is `e <= k - 1`; false is `e >= k`
    exists(int bound, boolean u | integerComparison(guard, e, bound, u) |
      val.asBooleanValue() = true and k = bound and upper = u
      or
      val.asBooleanValue() = false and
      (
        u = true and k = bound + 1 and upper = false
        or
        u = false and k = bound - 1 and upper = true
      )
    )
  }
}

/** A value a guard can evaluate to: a Boolean, null or not null, a constant, a match, … */
class GuardValue = GuardsImpl::GuardValue;

private module GuardsLogic = GuardsImpl::Logic<LogicInput>;

/**
 * A guard: an expression whose value decides which way control goes, or a `case`
 * alternative (`true` when it matches).
 */
final class Guard extends GuardsLogic::Guard {
  /** Gets the body whose graph this guard is in. */
  CfgScope getEnclosingCallable() { result = this.getBasicBlock().getScope() }
}
