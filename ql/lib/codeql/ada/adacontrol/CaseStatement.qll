/**
 * AdaControl rule `Case_Statement`: metrics of `case` statements: the number of paths, the
 * values of the selector's subtype, the values `when others` and range choices cover
 * (`docs/adacontrol.md`).
 *
 * Value counts need static values: here integer literals (possibly negated), character
 * literals, enumeration literals, named numbers, and ranges and subtypes made of them.
 * Where a bound or a choice is not one of these, the count is unknown (no result).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module CaseStatement {
  /** Gets `e` without the parentheses around it. */
  private Raw::Expr unparen(Raw::Expr e) {
    if e instanceof Raw::ParenExpr then result = unparen(e.(Raw::ParenExpr).getExpr()) else result = e
  }

  /**
   * Gets the static value of `e`: an integer literal, a character literal (its code), an
   * enumeration literal (its position), a named number, possibly negated.
   */
  int staticValue(Raw::Expr e) {
    result = staticValue0(e) and result.abs() < 2.pow(30)
  }

  private int staticValue0(Raw::Expr e) {
    exists(Raw::Expr u | u = unparen(e) |
      result = u.(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
      or
      result = u.(Raw::CharLiteral).getValue().charAt(1).codePointAt(0) and
      not exists(u.(Raw::CharLiteral).getReferencedDecl().(Raw::EnumLiteralDecl).getParentIndex())
      or
      exists(Raw::EnumLiteralDecl lit | lit = u.(Raw::Name).getReferencedDecl() |
        result = lit.getParentIndex()
      )
      or
      result = staticValue(u.(Raw::Name).getReferencedDecl().(Raw::NumberDecl).getExpr())
      or
      u.(Raw::UnOp).getOp() instanceof Raw::OpMinus and result = -staticValue(u.(Raw::UnOp).getExpr())
      or
      exists(Raw::BinOp p | p = u and p.getOp() instanceof Raw::OpPow |
        staticValue(p.getLeft()) = 2 and
        staticValue(p.getRight()) < 30 and
        result = 2.pow(staticValue(p.getRight())).floor()
      )
    )
  }

  /** Gets the number of values of range `L .. H` with static bounds (0 for a null range). */
  private int rangeValues(Raw::BinOp r) {
    r.getOp() instanceof Raw::OpDoubleDot and
    exists(int lo, int hi | lo = staticValue(r.getLeft()) and hi = staticValue(r.getRight()) |
      if hi >= lo then result = hi - lo + 1 else result = 0
    )
  }

  /** Gets the range constraint of subtype indication `si`, if any. */
  private Raw::BinOp rangeConstraint(Raw::SubtypeIndication si) {
    result = si.getConstraint().(Raw::RangeConstraint).getRange().getRange()
  }

  /** Gets the number of values of discrete type or subtype `t`, where it is static. */
  int typeValues(Type t) {
    t.hasQualifiedName("Standard.Character") and result = 256
    or
    t.hasQualifiedName("Standard.Wide_Character") and result = 65536
    or
    not t.hasQualifiedName(["Standard.Character", "Standard.Wide_Character", "Standard.Wide_Wide_Character"]) and
    result = typeValues0(t) and
    result > 0
  }

  private int typeValues0(Type t) {
    exists(Raw::SubtypeIndication si | si = t.(Raw::SubtypeDecl).getSubtype() |
      result = rangeValues(rangeConstraint(si))
      or
      not exists(rangeConstraint(si)) and result = typeValues(namedType(si))
    )
    or
    exists(Raw::TypeDef d | d = t.getDefinition() |
      result = count(d.(Raw::EnumTypeDef).getEnumLiterals().getChild(_))
      or
      result = rangeValues(d.(Raw::SignedIntTypeDef).getRange().getRange())
      or
      result = staticValue(d.(Raw::ModIntTypeDef).getExpr())
      or
      exists(Raw::SubtypeIndication si | si = d.(Raw::DerivedTypeDef).getSubtypeIndication() |
        result = rangeValues(rangeConstraint(si))
        or
        not exists(rangeConstraint(si)) and result = typeValues(namedType(si))
      )
    )
  }

  /** `values`: the number of values of the subtype of the selector of case statement `c`. */
  int values(Raw::CaseStmt c) {
    result = typeValues(c.getExpr().getType()) and
    // one subtype, one count
    strictcount(typeValues(c.getExpr().getType())) = 1
  }

  /** Gets the category of the selector of `c`: `()`, `range` or `mod` (derivations traversed). */
  string selectorCategory(Raw::CaseStmt c) {
    result = TypeCategories::category(c.getExpr().getType(), false)
  }

  /** `paths`: the number of alternatives (`when` branches) of `c`. */
  int paths(Raw::CaseStmt c) { result = count(c.getAlternatives().getChild(_)) }

  /** Gets a choice of an alternative of `c` other than `others`. */
  private Raw::AdaNode aChoice(Raw::CaseStmt c) {
    result = c.getAlternatives().getChild(_).(Raw::CaseStmtAlternative).getChoices().getChild(_) and
    not result instanceof Raw::OthersDesignator
  }

  /** Gets the number of values choice `ch` covers, where static. */
  int choiceValues(Raw::AdaNode ch) {
    exists(staticValue(ch)) and result = 1
    or
    result = rangeValues(ch)
    or
    result = typeValues(ch.(Raw::Name).getReferencedDecl())
    or
    result = typeValues(namedType(ch.(Raw::SubtypeIndication)))
  }

  /** `range_span`: the number of values range choice `ch` of `c` covers. */
  int rangeSpan(Raw::CaseStmt c, Raw::BinOp ch) { ch = aChoice(c) and result = rangeValues(ch) }

  /** Holds if `c` has a `when others` alternative. */
  predicate hasOthers(Raw::CaseStmt c) {
    c.getAlternatives().getChild(_).(Raw::CaseStmtAlternative).getChoices().getChild(_) instanceof
      Raw::OthersDesignator
  }

  /**
   * `others_span`: the number of values the `when others` alternative of `c` covers: the
   * selector's values less those of the other choices. Only when all are static.
   */
  int othersSpan(Raw::CaseStmt c) {
    hasOthers(c) and
    forall(Raw::AdaNode ch | ch = aChoice(c) | strictcount(choiceValues(ch)) = 1) and
    result = values(c) - sum(Raw::AdaNode ch | ch = aChoice(c) | choiceValues(ch)) and
    result >= 0
  }

  /** `values_if_others`: `values` of `c`, for a case statement with a `when others`. */
  int valuesIfOthers(Raw::CaseStmt c) { hasOthers(c) and result = values(c) }
}
