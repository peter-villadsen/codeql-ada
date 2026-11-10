/**
 * AdaControl rule `No_Operator_Usage`: integer types on which no arithmetic operator
 * is used: candidates for an enumeration type, or, for a modular type used only with
 * logical operators, for an array of Booleans (`docs/adacontrol.md`).
 *
 * An operator is used on a type when one of its operands, or its result, is of that
 * type or a subtype of it. Predefined and user-defined operators are not told apart,
 * as in AdaControl; an operator passed as a generic actual is not a use.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module NoOperatorUsage {
  /**
   * Gets the type `t` is a view of: through subtypes to the type they constrain, and
   * from a private view to its full view. A derived type is a type of its own.
   */
  Type root(Type t) {
    if t.isSubtype()
    then result = root(t.getParentType())
    else
      if exists(TypeCategories::fullView(t))
      then result = root(TypeCategories::fullView(t))
      else result = t
  }

  /**
   * Holds if `t` is an integer type declared in the source, of `category` `range`
   * (signed) or `mod` (modular): the full declaration, not a subtype, a private view
   * or a generic formal.
   */
  predicate isIntegerType(Type t, string category) {
    t.fromSource() and
    not t.isSubtype() and
    not t.isPrivate() and
    not t.getParent+() instanceof Raw::GenericFormalPart and
    category = TypeCategories::category(t, true) and
    category = ["range", "mod"]
  }

  /** Gets the type of expression `e`, as `root` sees it. */
  private Type exprType(Raw::Expr e) { result = root(e.getType()) }

  /** Holds if `op` is an arithmetic operator: `+`, `-`, `*`, `/`, `mod`, `rem`, `**`, `abs`. */
  private predicate isArithmetic(Raw::Op op) {
    op instanceof Raw::OpPlus or
    op instanceof Raw::OpMinus or
    op instanceof Raw::OpMult or
    op instanceof Raw::OpDiv or
    op instanceof Raw::OpMod or
    op instanceof Raw::OpRem or
    op instanceof Raw::OpPow or
    op instanceof Raw::OpAbs
  }

  /** Gets an operand of binary operator `b` whose type is the operator's type: not the exponent of `**`. */
  private Raw::Expr typedOperand(Raw::BinOp b) {
    result = b.getLeft()
    or
    result = b.getRight() and not b.getOp() instanceof Raw::OpPow
  }

  /** Holds if an arithmetic operator is used on `t`. */
  predicate usesArithmetic(Type t) {
    exists(Raw::BinOp b | isArithmetic(b.getOp()) |
      t = exprType(typedOperand(b)) or t = exprType(b)
    )
    or
    exists(Raw::UnOp u | isArithmetic(u.getOp()) | t = exprType(u.getExpr()) or t = exprType(u))
  }

  /** `relational`: `<`, `<=`, `>`, `>=`, `in` or `not in` is used on `t`. */
  predicate usesRelational(Type t) {
    exists(Raw::BinOp b |
      b.getOp() instanceof Raw::OpLt or
      b.getOp() instanceof Raw::OpLte or
      b.getOp() instanceof Raw::OpGt or
      b.getOp() instanceof Raw::OpGte
    |
      t = exprType(b.getLeft()) or t = exprType(b.getRight())
    )
    or
    exists(Raw::MembershipExpr m | t = exprType(m.getExpr()))
  }

  /** `logical`: `and`, `or` or `xor` is used on `t`. */
  predicate usesLogical(Type t) {
    exists(Raw::BinOp b |
      b.getOp() instanceof Raw::OpAnd or
      b.getOp() instanceof Raw::OpOr or
      b.getOp() instanceof Raw::OpXor
    |
      t = exprType(b.getLeft()) or t = exprType(b.getRight()) or t = exprType(b)
    )
  }

  /** `indexing`: `t`, or a subtype of it, is an index of an array type. */
  predicate isIndex(Type t) {
    exists(Raw::ArrayTypeDef a, Raw::AdaNode n | n.getParent+() = a.getIndices() |
      t = root(n.(Raw::Name).getReferencedDecl())
      or
      t = exprType(n)
    )
  }

  /**
   * Holds if integer type `t` of `category` has no arithmetic operator used on it,
   * the rule's base condition; `relational`, `logical` and `indexing` are filters on
   * top.
   */
  predicate noArithmetic(Type t, string category) {
    isIntegerType(t, category) and not usesArithmetic(t)
  }
}
