/**
 * AdaControl rule `Insufficient_Parameters`: calls whose positional actuals are only
 * literals, which do not tell the reader what they are for (`Draw (3, True)`)
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Declarations

module InsufficientParameters {
  /** The enumeration types whose literals do not convey a purpose (AdaControl's `<entity>` list). */
  signature predicate enumerationType(Type t);

  module Make<enumerationType/1 isEnumeration> {
    /** Holds if `e` is a primary that conveys no purpose: a numeric literal, or a literal of a listed enumeration. */
    private predicate isInsufficientPrimary(Raw::Expr e) {
      e instanceof Raw::NumLiteral
      or
      exists(Raw::EnumLiteralDecl lit, Type t |
        lit = e.(Raw::Name).getReferencedDecl() and
        isEnumeration(t) and
        lit = t.getAnEnumerationLiteral()
      )
    }

    /** Holds if every primary of `e` is insufficient (operators and parentheses aside). */
    private predicate isInsufficient(Raw::Expr e) {
      isInsufficientPrimary(e)
      or
      isInsufficient(e.(Raw::ParenExpr).getExpr())
      or
      isInsufficient(e.(Raw::UnOp).getExpr())
      or
      isInsufficient(e.(Raw::BinOp).getLeft()) and isInsufficient(e.(Raw::BinOp).getRight())
    }

    /**
     * Holds if `actual` is an insufficient actual of `call`: given by position, and only
     * numeric literals or listed enumeration literals. Not for operators, whose operands
     * cannot be named.
     */
    predicate insufficientActual(Call call, Raw::Expr actual) {
      not call instanceof Raw::BinOp and
      not call instanceof Raw::UnOp and
      actual = call.getAnArgument() and
      actual.getParent() instanceof Raw::ParamAssoc and
      not exists(actual.getParent().(Raw::ParamAssoc).getDesignator()) and
      isInsufficient(actual)
    }

    /** Gets the number of insufficient actuals of `call`. */
    int insufficientCount(Call call) {
      result = strictcount(Raw::Expr a | insufficientActual(call, a))
    }
  }
}
