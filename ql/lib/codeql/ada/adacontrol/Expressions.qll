/**
 * AdaControl rule `Expressions`: uses of given forms of expressions. `expression(e, kw)`
 * holds for each AdaControl `<expression_kw>` that applies to `e`
 * (`docs/adacontrol.md` lists the keywords implemented).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Calls
private import codeql.ada.Declarations as D
private import codeql.ada.adacontrol.TypeCategories

module Expressions {
  /** Gets the category of the type of `e`, derivations traversed (`TypeCategories`). */
  string typeCategory(Raw::Expr e) { result = TypeCategories::category(e.getType(), true) }

  /** Holds if the type of `e` is `Standard.Boolean` or derived from it. */
  predicate isBoolean(Raw::Expr e) {
    TypeCategories::ultimateType(e.getType()).hasQualifiedName("Standard.Boolean")
  }

  /** Gets the AdaControl keyword of the operator of `e`: `and`, `or_else`, `not_in`, ... */
  string operatorKeyword(Raw::Expr e) {
    exists(Raw::Op op | op = [e.(Raw::BinOp).getOp(), e.(Raw::UnOp).getOp(), e.(Raw::MembershipExpr).getOp()] |
      op instanceof Raw::OpAnd and result = "and"
      or
      op instanceof Raw::OpOr and result = "or"
      or
      op instanceof Raw::OpXor and result = "xor"
      or
      op instanceof Raw::OpAndThen and result = "and_then"
      or
      op instanceof Raw::OpOrElse and result = "or_else"
      or
      op instanceof Raw::OpNot and result = "not"
      or
      op instanceof Raw::OpIn and result = "in"
      or
      op instanceof Raw::OpNotIn and result = "not_in"
    )
  }

  /** Gets the operator of binary or membership expression `e`, as a token, for `mixed_operators`. */
  private string binaryOperator(Raw::Expr e) {
    result = e.(Raw::BinOp).getOp().getAPrimaryQlClass()
    or
    result = e.(Raw::MembershipExpr).getOp().getAPrimaryQlClass()
  }

  /** Gets an operand of binary or membership expression `e`. */
  private Raw::Expr anOperand(Raw::Expr e) {
    result = [e.(Raw::BinOp).getLeft(), e.(Raw::BinOp).getRight(), e.(Raw::MembershipExpr).getExpr()]
  }

  /** Holds if aggregate `a` has an `others =>` association; `partial` if also other ones. */
  private predicate hasOthers(Raw::BaseAggregate a, boolean partial) {
    exists(Raw::AggregateAssoc o |
      o = a.getAssocs().getChild(_) and
      o.getDesignators().getChild(_) instanceof Raw::OthersDesignator
    |
      if exists(Raw::AdaNode other | other = a.getAssocs().getChild(_) and other != o)
      then partial = true
      else partial = false
    )
  }

  /** Holds if aggregate `a` has a positional (not named) association. */
  private predicate hasPositional(Raw::BaseAggregate a) {
    exists(Raw::AggregateAssoc p | p = a.getAssocs().getChild(_) | not exists(p.getDesignators().getChild(_)))
  }

  /** Holds if `e` is a discrete range: `A .. B`, `X'Range`, or a subtype name. */
  private predicate isRange(Raw::AdaNode e) {
    e.(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot
    or
    e.(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "range"
    or
    e.(Raw::Name).getReferencedDecl() instanceof Raw::BaseTypeDecl
    or
    e instanceof Raw::SubtypeIndication
  }

  /** Holds if `conv` is a type conversion `T (X)`, of `operand` to `target`. */
  predicate isConversion(Raw::CallExpr conv, Raw::Expr operand, D::Type target) {
    target = conv.getName().getReferencedDecl() and
    operand = conv.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr() and
    not exists(conv.getSuffix().(Raw::AssocList).getChild(1))
  }

  /** Gets the root of the derivation family of `t`: through subtypes, derivations and private views. */
  private D::Type root(D::Type t) {
    exists(D::Type u | u = t or u = TypeCategories::fullView(t) |
      if exists(u.getParentType()) then result = root(u.getParentType()) else result = u
    )
  }

  /** Holds if `t` is derived from `ancestor`, directly or not (through subtypes and views). */
  private predicate derivedFrom(D::Type t, D::Type ancestor) {
    exists(D::Type p | p = t.getParentType() or p = TypeCategories::fullView(t).getParentType() |
      TypeCategories::sameType(p, ancestor) or derivedFrom(p, ancestor)
    )
  }

  /** Holds if `call` is a call to a function the project declares or the runtime does, not a predefined operator. */
  private predicate isFunctionCall(Call call) {
    call.getTarget().isFunction() and
    not call.getTarget().getEnclosingUnit().getBody().(Raw::LibraryItem).getItem().(D::Package).hasName("Standard")
  }

  /** Holds if `e` is or contains a call: a function call or any operator. */
  private predicate containsCall(Raw::Expr e) {
    exists(Raw::Expr c | c.getParent*() = e |
      c instanceof Call or c instanceof Raw::BinOp or c instanceof Raw::UnOp
    )
  }

  /** Holds if `e` is of a kind AdaControl's `Expressions` names `kw`. */
  predicate expression(Raw::Expr e, string kw) {
    // logical operators, short circuits and membership tests
    kw = operatorKeyword(e)
    or
    exists(string op | op = operatorKeyword(e) and op = ["and", "or", "xor"] |
      typeCategory(e) = "array" and kw = op + "_array"
      or
      typeCategory(e) = "mod" and kw = op + "_binary"
      or
      isBoolean(e) and kw = op + "_boolean"
    )
    or
    // aggregates
    exists(Raw::BaseAggregate a | a = e |
      typeCategory(a) = "array" and kw = "array_aggregate"
      or
      typeCategory(a) = ["record", "tagged", "extension"] and kw = "record_aggregate"
      or
      not a.getParent() instanceof Raw::QualExpr and kw = "unqualified_aggregate"
      or
      exists(a.getAncestorExpr()) and kw = "extension_aggregate"
      or
      typeCategory(a) = "array" and
      (
        hasOthers(a, _) and kw = "array_others"
        or
        hasOthers(a, true) and kw = "array_partial_others"
        or
        hasOthers(a, true) and hasPositional(a) and kw = "array_positional_others"
        or
        hasOthers(a, true) and not hasPositional(a) and kw = "array_named_others"
        or
        exists(Raw::AggregateAssoc r | r = a.getAssocs().getChild(_) |
          isRange(r.getDesignators().getChild(_))
        ) and
        kw = "array_range"
      )
      or
      typeCategory(a) = ["record", "tagged", "extension"] and
      (
        hasOthers(a, _) and kw = "record_others"
        or
        hasOthers(a, true) and kw = "record_partial_others"
      )
    )
    or
    // conditional and quantified expressions
    e instanceof Raw::CaseExpr and kw = "case"
    or
    exists(Raw::IfExpr i | i = e |
      kw = "if"
      or
      exists(i.getAlternatives().getChild(_)) and kw = "if_elsif"
      or
      not exists(i.getElseExpr()) and kw = "if_no_else"
    )
    or
    e.(Raw::QuantifiedExpr).getQuantifier() instanceof Raw::QuantifierAll and kw = "for_all"
    or
    e.(Raw::QuantifiedExpr).getQuantifier() instanceof Raw::QuantifierSome and kw = "for_some"
    or
    // names
    e instanceof Raw::ExplicitDeref and kw = "explicit_dereference"
    or
    // `A (1 .. 2)` has the range as its suffix; `A (Index)` an argument list
    exists(Raw::CallExpr s | s = e and typeCategory(s.getName()) = "array" |
      isRange(s.getSuffix())
      or
      isRange(s.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr()) and
      not exists(s.getSuffix().(Raw::AssocList).getChild(1))
    ) and
    kw = "slice"
    or
    e instanceof Raw::TargetName and kw = "target_name"
    or
    e instanceof Raw::TargetName and
    e.getParent+().(Raw::AssignStmt).getDest() instanceof Raw::Identifier and
    kw = "trivial_target_name"
    or
    // calls
    isFunctionCall(e) and kw = "function_call"
    or
    exists(Raw::CallExpr c | c = e |
      c.getName() instanceof Raw::ExplicitDeref
      or
      typeCategory(c.getName()) = "access"
    ) and
    kw = "dynamic_function_call"
    or
    exists(Raw::CallExpr c | c = e |
      c.getName().(Raw::StringLiteral).getValue().regexpMatch("\"[^\"]+\"") or
      c.getName().(Raw::DottedName).getSuffix() instanceof Raw::StringLiteral
    ) and
    kw = "prefixed_operator"
    or
    exists(Call c, Raw::Expr actual |
      actual = e and
      actual = c.getAnArgument() and
      not c instanceof Raw::BinOp and
      not c instanceof Raw::UnOp and
      containsCall(actual)
    ) and
    kw = "complex_parameter"
    or
    // operators on real types
    exists(Raw::BinOp eq | eq = e |
      (eq.getOp() instanceof Raw::OpEq or eq.getOp() instanceof Raw::OpNeq) and
      typeCategory(eq.getLeft()) = ["digits", "delta"] and
      not eq instanceof Call and
      kw = "real_equality"
    )
    or
    exists(Raw::BinOp m | m = e |
      (m.getOp() instanceof Raw::OpMult or m.getOp() instanceof Raw::OpDiv) and
      typeCategory(m) = "delta" and
      not m instanceof Call and
      kw = "fixed_multiplying_op"
    )
    or
    // mixed operators: an operand of a binary operator is an unparenthesized binary
    // operator of another kind, or `-A mod B`
    exists(Raw::Expr operand | operand = anOperand(e) |
      exists(binaryOperator(operand)) and
      binaryOperator(operand) != binaryOperator(e) and
      kw = "mixed_operators"
    )
    or
    exists(Raw::UnOp u | u = e |
      (u.getOp() instanceof Raw::OpMinus or u.getOp() instanceof Raw::OpPlus) and
      exists(Raw::BinOp b | b = u.getExpr() |
        b.getOp() instanceof Raw::OpMod or b.getOp() instanceof Raw::OpRem
      ) and
      kw = "mixed_operators"
    )
    or
    // conversions
    isConversion(e, _, _) and kw = "type_conversion"
    or
    exists(Raw::Expr operand, D::Type target, D::Type source |
      isConversion(e, operand, target) and source = operand.getType()
    |
      not root(source) = root(target) and kw = "underived_conversion"
      or
      derivedFrom(target, source) and kw = "downward_conversion"
      or
      derivedFrom(source, target) and kw = "upward_conversion"
    )
    or
    exists(Raw::Expr operand, D::Type target, Call c, Parameter p |
      isConversion(e, operand, target) and
      e = c.getArgumentFor(p) and
      p.isOut() and
      kw = "parameter_view_conversion"
    )
  }
}
