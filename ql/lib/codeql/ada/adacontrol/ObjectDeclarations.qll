/**
 * AdaControl rule `Object_Declarations`: constants and variables, by the span of their
 * integer subtype, by type, and volatile without address or with an address but not
 * volatile (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations

module ObjectDeclarations {
  /** Holds if `d` is the declaration of a constant (`isConstant`) or a variable, not a renaming. */
  predicate isObject(Raw::ObjectDecl d, boolean isConstant) {
    not exists(d.getRenamingClause()) and
    not d.getParent() instanceof Raw::GenericFormal and
    not d instanceof Raw::ExtendedReturnStmtObjectDecl and
    if d.getHasConstant() instanceof Raw::ConstantPresent
    then isConstant = true
    else isConstant = false
  }

  /** Gets the value of `e` if it is an integer literal, possibly negated. */
  private int literalValue(Raw::Expr e) {
    result = e.(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
    or
    e.(Raw::UnOp).getOp() instanceof Raw::OpMinus and
    result = -literalValue(e.(Raw::UnOp).getExpr())
  }

  /** Gets the range `L .. H` constraining subtype indication `si`, or the range of the type it names. */
  private Raw::BinOp rangeOf(Raw::AdaNode si) {
    result = si.(Raw::SubtypeIndication).getConstraint().(Raw::RangeConstraint).getRange().getRange()
    or
    not exists(si.(Raw::SubtypeIndication).getConstraint()) and
    exists(Type t | t = si.(Raw::SubtypeIndication).getName().getReferencedDecl() |
      result = rangeOf(t.(Raw::SubtypeDecl).getSubtype())
      or
      result = t.getDefinition().(Raw::SignedIntTypeDef).getRange().getRange()
    )
  }

  /**
   * `min_integer_span`: the number of values of the integer subtype of object `d`, where
   * its range has literal bounds (`range 1 .. 10`, through subtype declarations).
   */
  int integerSpan(Raw::ObjectDecl d) {
    exists(Raw::BinOp r | r = rangeOf(d.getTypeExpr()) and r.getOp() instanceof Raw::OpDoubleDot |
      result = literalValue(r.getRight()) - literalValue(r.getLeft()) + 1
    )
  }

  /** `type`: object `d` is declared with type `t`, or a subtype of it (`exact` if `t` itself). */
  predicate hasType(Raw::ObjectDecl d, Type t, boolean exact) {
    exists(Type declared | declared = namedType(d.getTypeExpr()) |
      declared = t and exact = true
      or
      declared != t and declared.isSubtype() and declared.getParentType+() = t and exact = false
    )
  }

  /** Holds if the aspect or pragma `name` (`volatile`, `address`, ...) applies to object `d`. */
  bindingset[name]
  private predicate hasAspectOrPragma(Raw::ObjectDecl d, string name) {
    exists(Raw::AspectAssoc a | a = d.getAspects().getAspectAssocs().getChild(_) |
      a.getId().(Raw::Name).getText().toLowerCase() = name and
      not a.getExpr().(Raw::Name).getText().toLowerCase() = "false"
    )
    or
    exists(Raw::PragmaNode p |
      p.getId().getValue().toLowerCase() = name and
      p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr().(Raw::Name).getReferencedDecl() = d
    )
  }

  /** Holds if variable `d` is volatile: `Volatile` or `Atomic` (which implies it), by aspect or pragma. */
  predicate isVolatile(Raw::ObjectDecl d) {
    hasAspectOrPragma(d, ["volatile", "atomic", "volatile_full_access"])
  }

  /** Holds if variable `d` has an address: an `Address` aspect, an attribute definition clause or an `at` clause. */
  predicate hasAddress(Raw::ObjectDecl d) {
    hasAspectOrPragma(d, "address")
    or
    exists(Raw::AttributeDefClause c |
      c.getAttributeExpr().(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "address" and
      c.getAttributeExpr().(Raw::AttributeRef).getPrefix().getReferencedDecl() = d
    )
    or
    exists(Raw::AtClause c | c.getName().getReferencedDecl() = d)
  }

  /** `volatile_no_address`: variable `d` is volatile but has no address. */
  predicate volatileNoAddress(Raw::ObjectDecl d) {
    isObject(d, false) and isVolatile(d) and not hasAddress(d)
  }

  /** `address_not_volatile`: variable `d` has an address but is not volatile. */
  predicate addressNotVolatile(Raw::ObjectDecl d) {
    isObject(d, false) and hasAddress(d) and not isVolatile(d)
  }
}
