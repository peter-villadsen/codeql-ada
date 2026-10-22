/**
 * AdaControl rule `Simplifiable_Expressions`: expressions that can be simplified
 * (`docs/adacontrol.md`). `simplifiable(e, subrule)` holds for each subrule that applies
 * to `e`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Expressions
private import codeql.ada.adacontrol.SimplifiableStatements

module SimplifiableExpressions {
  private Raw::Expr unparen(Raw::Expr e) { result = SimplifiableStatements::unparen(e) }

  /** Holds if `e` is of a universal type: a numeric literal or a named number. */
  private predicate isUniversal(Raw::Expr e) {
    unparen(e) instanceof Raw::NumLiteral or
    unparen(e).(Raw::Name).getReferencedDecl() instanceof Raw::NumberDecl
  }

  /** Gets the first named subtype of `t`: through subtype declarations to the type. */
  private Type firstSubtype(Type t) {
    if t.isSubtype() and exists(t.getParentType())
    then result = firstSubtype(t.getParentType())
    else result = t
  }

  /**
   * `conversion`: conversion `e` (`T (X)`) of a universal value, or to the subtype of its
   * operand, or to the first named subtype of the operand's type.
   */
  predicate isRedundantConversion(Raw::CallExpr e) {
    exists(Raw::Expr operand, Type target | Expressions::isConversion(e, operand, target) |
      isUniversal(operand)
      or
      target = operand.getType()
      or
      target = firstSubtype(operand.getType()) and not target.isSubtype()
    )
  }

  /** Holds if `op` is a relational operator: `=`, `/=`, `<`, `<=`, `>`, `>=`. */
  private predicate isComparison(Raw::Op op) {
    op instanceof Raw::OpEq or
    op instanceof Raw::OpNeq or
    op instanceof Raw::OpLt or
    op instanceof Raw::OpLte or
    op instanceof Raw::OpGt or
    op instanceof Raw::OpGte
  }

  /** Holds if `op` is `and`, `or`, `and then` or `or else`. */
  private predicate isLogical(Raw::Op op) {
    op instanceof Raw::OpAnd or
    op instanceof Raw::OpOr or
    op instanceof Raw::OpAndThen or
    op instanceof Raw::OpOrElse
  }

  /**
   * Gets the precedence level of the operator of `e` (Ada RM 4.5): 1 logical, 2
   * relational and membership, 3 binary adding, 4 unary adding, 5 multiplying, 6 highest
   * (`**`, `abs`, `not`).
   */
  int precedence(Raw::Expr e) {
    exists(Raw::Op op | op = e.(Raw::BinOp).getOp() |
      (isLogical(op) or op instanceof Raw::OpXor) and result = 1
      or
      isComparison(op) and result = 2
      or
      (op instanceof Raw::OpPlus or op instanceof Raw::OpMinus or op instanceof Raw::OpConcat) and
      result = 3
      or
      (op instanceof Raw::OpMult or op instanceof Raw::OpDiv or op instanceof Raw::OpMod or op instanceof Raw::OpRem) and
      result = 5
      or
      op instanceof Raw::OpPow and result = 6
    )
    or
    e instanceof Raw::ConcatOp and result = 3
    or
    e instanceof Raw::MembershipExpr and result = 2
    or
    exists(Raw::Op op | op = e.(Raw::UnOp).getOp() |
      (op instanceof Raw::OpPlus or op instanceof Raw::OpMinus) and result = 4
      or
      (op instanceof Raw::OpAbs or op instanceof Raw::OpNot) and result = 6
    )
  }

  /** Holds if `e` is a primary: a name, a literal, an aggregate, a call. */
  private predicate isPrimary(Raw::Expr e) {
    e instanceof Raw::Name or e instanceof Raw::NumLiteral or e instanceof Raw::BaseAggregate
  }

  /**
   * `parentheses`: parentheses `p` that are not needed: around the whole expression of an
   * assignment, a condition, a `case` selector or a `return`; around a primary that is an
   * operand; around an operand whose operator binds more tightly than the one it is an
   * operand of (not of equal precedence: AdaControl does not report those).
   */
  predicate isUnnecessaryParentheses(Raw::ParenExpr p) {
    // a conditional, quantified or declare expression must be parenthesized
    not p.getExpr() instanceof Raw::CondExpr and
    not p.getExpr() instanceof Raw::QuantifiedExpr and
    not p.getExpr() instanceof Raw::DeclExpr and
    (
      p = any(Raw::AssignStmt a).getExpr()
      or
      p = any(Raw::IfStmt i).getCondExpr()
      or
      p = any(Raw::ElsifStmtPart e).getCondExpr()
      or
      p = any(Raw::CaseStmt c).getExpr()
      or
      p = any(Raw::ReturnStmt r).getReturnExpr()
      or
      p = any(Raw::WhileLoopSpec w).getExpr()
      or
      exists(Raw::Expr parent | exists(precedence(parent)) and p.getParent() = parent |
        isPrimary(p.getExpr())
        or
        precedence(p.getExpr()) > precedence(parent)
      )
    )
  }

  /** Gets the leaves of a chain of the same logical operator `op` rooted at `e`. */
  private Raw::Expr leaf(Raw::BinOp chain, string op) {
    op = chain.getOp().getAPrimaryQlClass() and
    exists(Raw::Expr operand | operand = [chain.getLeft(), chain.getRight()] |
      if operand.(Raw::BinOp).getOp().getAPrimaryQlClass() = op
      then result = leaf(operand, op)
      else result = operand
    )
  }

  /** Holds if `leaf` tests `x` for (in)equality or membership: `x = E`, `x in ...` (`positive`), or `x /= E`, `x not in ...`. */
  private predicate testsVariable(Raw::Expr leaf, Raw::Name x, boolean positive) {
    exists(Raw::BinOp b | b = unparen(leaf) and x = b.getLeft() |
      b.getOp() instanceof Raw::OpEq and positive = true
      or
      b.getOp() instanceof Raw::OpNeq and positive = false
    )
    or
    exists(Raw::MembershipExpr m | m = unparen(leaf) and x = m.getExpr() |
      m.getOp() instanceof Raw::OpIn and positive = true
      or
      m.getOp() instanceof Raw::OpNotIn and positive = false
    )
  }

  /**
   * `membership`: `e` is a chain of tests of one variable that one membership test can
   * replace: equalities and `in` tests joined by `or`, inequalities and `not in` tests
   * joined by `and`.
   */
  predicate isMembershipChain(Raw::BinOp e) {
    not e.getParent().(Raw::BinOp).getOp().getAPrimaryQlClass() = e.getOp().getAPrimaryQlClass() and
    exists(string op, boolean positive, Raw::Name x |
      (
        op = ["OpOr", "OpOrElse"] and positive = true
        or
        op = ["OpAnd", "OpAndThen"] and positive = false
      ) and
      testsVariable(leaf(e, op), x, positive) and
      forex(Raw::Expr l | l = leaf(e, op) |
        exists(Raw::Name y | testsVariable(l, y, positive) | y.denotesSameEntityAs(x) or y = x)
      )
    )
  }

  /** Holds if `e` is of the kind AdaControl's `Simplifiable_Expressions` names `subrule`. */
  predicate simplifiable(Raw::Expr e, string subrule) {
    isRedundantConversion(e) and subrule = "conversion"
    or
    exists(Raw::IfExpr i | i = e |
      exists(i.getElseExpr()) and
      not exists(i.getAlternatives().getChild(_)) and
      (
        unparen(i.getCondExpr()).(Raw::UnOp).getOp() instanceof Raw::OpNot or
        unparen(i.getCondExpr()).(Raw::BinOp).getOp() instanceof Raw::OpNeq
      )
    ) and
    subrule = "if_not"
    or
    exists(Raw::BinOp b, boolean value | b = e |
      (b.getOp() instanceof Raw::OpEq or b.getOp() instanceof Raw::OpNeq) and
      SimplifiableStatements::isStaticBoolean([b.getLeft(), b.getRight()], value) and
      (
        value = true and subrule = "logical_true"
        or
        value = false and subrule = "logical_false"
      )
    )
    or
    exists(Raw::BinOp b | b = e |
      isLogical(b.getOp()) and
      SimplifiableStatements::sameExpr(unparen(b.getLeft()), unparen(b.getRight()))
    ) and
    subrule = "logical_redundant"
    or
    exists(Raw::UnOp u | u = e |
      u.getOp() instanceof Raw::OpNot and isComparison(unparen(u.getExpr()).(Raw::BinOp).getOp())
    ) and
    subrule = "logical_not"
    or
    isMembershipChain(e) and subrule = "membership"
    or
    isUnnecessaryParentheses(e) and subrule = "parentheses"
    or
    exists(Raw::BinOp r, Raw::AttributeRef first, Raw::AttributeRef last |
      r = e and
      r.getOp() instanceof Raw::OpDoubleDot and
      first = r.getLeft() and
      last = r.getRight() and
      first.getAttribute().getValue().toLowerCase() = "first" and
      last.getAttribute().getValue().toLowerCase() = "last" and
      not exists(first.getArgs().getChild(_)) and
      not exists(last.getArgs().getChild(_)) and
      first.getPrefix().getText().toLowerCase() = last.getPrefix().getText().toLowerCase()
    ) and
    subrule = "range"
  }
}
