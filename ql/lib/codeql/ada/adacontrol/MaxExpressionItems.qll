/**
 * AdaControl rule `Max_Expression_Items`: expressions with too many primaries
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module MaxExpressionItems {
  /** Holds if `e` combines operands: a binary or unary operator, a membership test, parentheses. */
  private predicate isComposite(Raw::Expr e) {
    e instanceof Raw::BinOp or
    e instanceof Raw::UnOp or
    e instanceof Raw::MembershipExpr or
    e instanceof Raw::ParenExpr
  }

  /** Gets a direct operand of composite expression `e`. */
  private Raw::Expr operand(Raw::Expr e) {
    result =
      [
        e.(Raw::BinOp).getLeft(), e.(Raw::BinOp).getRight(), e.(Raw::UnOp).getExpr(),
        e.(Raw::ParenExpr).getExpr(), e.(Raw::MembershipExpr).getExpr()
      ]
    or
    result = e.(Raw::MembershipExpr).getMembershipExprs().getChild(_)
  }

  /**
   * Gets the number of primaries of `e`: 1 for a primary (a name, a literal, a call, an
   * aggregate, ...), the sum over the operands of a composite expression.
   */
  int items(Raw::Expr e) {
    not isComposite(e) and result = 1
    or
    isComposite(e) and
    result = count(Raw::Expr leaf | leaf = operand+(e) and not isComposite(leaf))
  }

  /**
   * Holds if `e` is a whole composite expression: not an operand of another. The
   * arguments of a call, the components of an aggregate, ... are whole expressions of
   * their own.
   */
  predicate isWhole(Raw::Expr e) {
    isComposite(e) and not exists(Raw::Expr parent | e = operand(parent))
  }
}
