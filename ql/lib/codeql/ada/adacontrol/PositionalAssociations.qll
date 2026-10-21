/**
 * AdaControl rule `Positional_Associations`: positional rather than named associations
 * in calls, discriminant constraints, pragmas, aggregates, instantiations and
 * enumeration representation clauses (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Declarations

module PositionalAssociations {
  /**
   * Holds if `list` holds the associations of a construct of kind `kind`: `call`,
   * `discriminant`, `pragma`, `record_aggregate`, `array_aggregate`, `instantiation`,
   * `enumeration_representation`; `site` is the construct.
   */
  predicate associations(Raw::AdaNode site, Raw::AdaNode list, string kind) {
    // a call written with parentheses; infix operators and attributes have no names
    site instanceof Call and
    list = site.(Raw::CallExpr).getSuffix() and
    kind = "call"
    or
    site = any(Raw::CallStmt s).getCall().(Call) and
    list = site.(Raw::CallExpr).getSuffix() and
    kind = "call"
    or
    site instanceof Raw::SubtypeIndication and
    list = site.(Raw::SubtypeIndication).getConstraint().(Raw::CompositeConstraint).getConstraints() and
    kind = "discriminant"
    or
    site instanceof Raw::PragmaNode and list = site.(Raw::PragmaNode).getArgs() and kind = "pragma"
    or
    exists(Raw::BaseAggregate a, string c | a = site and list = a.getAssocs() |
      c = categoryOf(a) and
      (
        c = "array" and
        if a.getParent() instanceof Raw::EnumRepClause
        then kind = "enumeration_representation"
        else kind = "array_aggregate"
        or
        c = "record" and kind = "record_aggregate"
      )
    )
    or
    list = site.(Raw::GenericPackageInstantiation).getParams() and kind = "instantiation"
    or
    list = site.(Raw::GenericSubpInstantiation).getParams() and kind = "instantiation"
  }

  /** Gets `array` or `record` for aggregate `a`, by its type, or by its form when the type is unknown. */
  private string categoryOf(Raw::BaseAggregate a) {
    exists(Type t | t = a.getType() |
      if t.isArray() or t.getParentType*().isArray() then result = "array" else result = "record"
    )
    or
    a.getParent() instanceof Raw::EnumRepClause and result = "array"
  }

  /** Holds if `assoc`, an element of association list `list`, is positional. */
  predicate isPositional(Raw::AdaNode list, Raw::AdaNode assoc) {
    associations(_, list, _) and
    assoc.getParent() = list and
    (
      assoc instanceof Raw::ParamAssoc and not exists(assoc.(Raw::ParamAssoc).getDesignator())
      or
      assoc instanceof Raw::PragmaArgumentAssoc and not exists(assoc.(Raw::PragmaArgumentAssoc).getName())
      or
      assoc instanceof Raw::AggregateAssoc and not exists(assoc.(Raw::AggregateAssoc).getDesignators().getChild(_))
      or
      assoc instanceof Raw::CompositeConstraintAssoc and
      not exists(assoc.(Raw::CompositeConstraintAssoc).getIds().getChild(_))
    )
  }

  /** Gets the expression of positional association `assoc`. */
  private Raw::Expr valueOf(Raw::AdaNode assoc) {
    result =
      [
        assoc.(Raw::ParamAssoc).getRExpr(), assoc.(Raw::PragmaArgumentAssoc).getExpr(),
        assoc.(Raw::AggregateAssoc).getRExpr(), assoc.(Raw::CompositeConstraintAssoc).getConstraintExpr().(Raw::Expr)
      ]
  }

  /** `all`: the number of associations of `list`, when at least one is positional. */
  int allCount(Raw::AdaNode list) {
    exists(Raw::AdaNode a | isPositional(list, a)) and result = count(Raw::AdaNode a | a.getParent() = list)
  }

  /** `all_positional`: the number of positional associations of `list`. */
  int positionalCount(Raw::AdaNode list) { result = strictcount(Raw::AdaNode a | isPositional(list, a)) }

  /** `same_type`: the largest number of positional associations of `list` whose values have the same type. */
  int sameTypeCount(Raw::AdaNode list) {
    result =
      max(Type t |
        exists(Raw::AdaNode a | isPositional(list, a) and valueOf(a).getType() = t)
      |
        count(Raw::AdaNode a | isPositional(list, a) and valueOf(a).getType() = t)
      )
  }

  /** `declared`: the number of parameters the callee (or generic) of `site` declares. */
  int declaredCount(Raw::AdaNode site) {
    result = site.(Call).getTarget().getNumberOfParameters()
  }

  /** Holds if `site` is an operator call written like a function call (`"+" (A, B)`), for `not_operator`. */
  predicate isPrefixedOperator(Raw::AdaNode site) {
    site.(Call).getTarget().getName().matches("\"%\"")
  }
}
