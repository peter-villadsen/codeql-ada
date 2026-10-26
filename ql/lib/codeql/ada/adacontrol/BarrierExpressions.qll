/**
 * AdaControl rule `Barrier_Expressions`: the constructs used in the barrier of a protected
 * entry. `construct(n, b, kw)` holds for each part `n` of the barrier of entry body `b`
 * that is something other than a reference to a Boolean component of the protected
 * element or a literal, with `kw` the AdaControl `<keyword>` that allows it, or `call`
 * for a call that only naming the function allows (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Declarations as D
private import codeql.ada.adacontrol.Expressions

module BarrierExpressions {
  /** Holds if `n` is part of the barrier of entry body `b`, or the barrier itself. */
  predicate inBarrier(Raw::AdaNode n, Raw::EntryBody b) { n.getParent*() = b.getBarrier() }

  /** Holds if `d` is declared in a protected type, a single protected object or a protected body. */
  private predicate inProtected(Raw::BasicDecl d) {
    d.getParent+() instanceof Raw::ProtectedDef or
    d.getParent+() instanceof Raw::ProtectedBody
  }

  /**
   * Holds if `n` is a name that refers to a declaration on its own: an identifier that is
   * not the selector of a dotted name, or a dotted name. Not an attribute designator, a
   * declared name or an `end` name.
   */
  private predicate isReference(Raw::Name n) {
    (
      n instanceof Raw::Identifier and not n = any(Raw::DottedName d).getSuffix()
      or
      n instanceof Raw::DottedName
    ) and
    not n = any(Raw::AttributeRef a).getAttribute() and
    not n.getParent() instanceof Raw::DefiningName and
    not n.getParent+() instanceof Raw::EndName
  }

  /** Holds if `n` names an object of an access type, so that selecting or indexing it dereferences it. */
  private predicate isAccessValue(Raw::Name n) { Expressions::typeCategory(n) = "access" }

  /** Holds if `d` is a function, or a subprogram body or renaming, whose spec says `function`. */
  private predicate isFunction(Raw::BasicDecl d) {
    exists(Raw::SubpSpec s |
      s = d.(Raw::ClassicSubpDecl).getSubpSpec() or s = d.(Raw::BaseSubpBody).getSubpSpec()
    |
      s.getSubpKind() instanceof Raw::SubpKindFunction
    )
  }

  /** Gets the keyword for a call to function `f`: `local_function` for a protected function of the same object, else `call`. */
  private string callKeyword(Raw::BasicDecl f) {
    isFunction(f) and
    if inProtected(f) then result = "local_function" else result = "call"
  }

  /** Gets the keyword of predefined operator `op`. */
  private string operatorKeyword(Raw::Op op) {
    (
      op instanceof Raw::OpEq or
      op instanceof Raw::OpNeq or
      op instanceof Raw::OpLt or
      op instanceof Raw::OpLte or
      op instanceof Raw::OpGt or
      op instanceof Raw::OpGte or
      op instanceof Raw::OpIn or
      op instanceof Raw::OpNotIn
    ) and
    result = "comparison_operator"
    or
    (
      op instanceof Raw::OpAnd or
      op instanceof Raw::OpOr or
      op instanceof Raw::OpXor or
      op instanceof Raw::OpAndThen or
      op instanceof Raw::OpOrElse or
      op instanceof Raw::OpNot
    ) and
    result = "logical_operator"
    or
    (
      op instanceof Raw::OpPlus or
      op instanceof Raw::OpMinus or
      op instanceof Raw::OpMult or
      op instanceof Raw::OpDiv or
      op instanceof Raw::OpMod or
      op instanceof Raw::OpRem or
      op instanceof Raw::OpPow or
      op instanceof Raw::OpAbs or
      op instanceof Raw::OpConcat
    ) and
    result = "arithmetic_operator"
  }

  /** Holds if operator expression `e` calls a user-defined operator, not a predefined one. */
  private predicate isUserOperator(Call e) {
    not e.getTarget().getEnclosingUnit().getBody().(Raw::LibraryItem).getItem().(D::Package).hasName("Standard")
  }

  /** Gets the keyword for construct `n`, wherever it is. */
  private string keyword(Raw::Expr n) {
    // names of objects and functions; the name of an indexing is a component or variable too
    isReference(n) and
    exists(Raw::BasicDecl d | d = n.(Raw::Name).getReferencedDecl() |
      d instanceof Raw::ComponentDecl and
      inProtected(d) and
      not Expressions::isBoolean(n) and
      result = "any_component"
      or
      (d instanceof Raw::ObjectDecl or d instanceof Raw::ParamSpec) and
      not inProtected(d) and
      result = "any_variable"
      or
      not n = any(Raw::CallExpr c).getName() and
      not n = any(Raw::AttributeRef a).getPrefix() and
      result = callKeyword(d)
    )
    or
    exists(Raw::CallExpr c | c = n and not c.getName() instanceof Raw::AttributeRef |
      c.getName().(Raw::Name).getReferencedDecl() instanceof Raw::BaseTypeDecl and
      result = "conversion"
      or
      Expressions::typeCategory(c.getName()) = "array" and result = "indexing"
      or
      // through an access value: an implicit dereference
      isAccessValue(c.getName()) and result = "dereference"
      or
      result = callKeyword(c.getName().(Raw::Name).getReferencedDecl())
    )
    or
    n instanceof Raw::QualExpr and result = "conversion"
    or
    n instanceof Raw::ExplicitDeref and result = "dereference"
    or
    // `Ptr.Field`: an implicit dereference
    exists(Raw::DottedName d | d = n |
      isAccessValue(d.getPrefix()) and
      d.getReferencedDecl() instanceof Raw::ComponentDecl and
      result = "dereference"
    )
    or
    n instanceof Raw::Allocator and result = "allocation"
    or
    exists(Raw::BaseAggregate a | a = n |
      if Expressions::typeCategory(a) = "array"
      then result = "array_aggregate"
      else result = "record_aggregate"
    )
    or
    exists(Raw::Op op |
      op = [n.(Raw::BinOp).getOp(), n.(Raw::UnOp).getOp(), n.(Raw::MembershipExpr).getOp()]
    |
      if isUserOperator(n) then result = "call" else result = operatorKeyword(op)
    )
    or
    n instanceof Raw::ConcatOp and result = "arithmetic_operator"
    or
    exists(Raw::AttributeRef a | a = n |
      if exists(a.getArgs().getChild(_)) or a = any(Raw::CallExpr c).getName()
      then result = "function_attribute"
      else result = "value_attribute"
    )
  }

  /**
   * Holds if `n`, part of the barrier of entry body `b`, is a construct that AdaControl's
   * keyword `kw` allows: `allocation`, `any_component`, `any_variable`,
   * `arithmetic_operator`, `array_aggregate`, `comparison_operator`, `conversion`,
   * `dereference`, `indexing`, `function_attribute`, `local_function`,
   * `logical_operator`, `record_aggregate`, `value_attribute`; or `call`, a call to a
   * function (or a user-defined operator) that only naming it allows. Boolean
   * components of the protected element, literals, named numbers and the entry family
   * index are always allowed and have no keyword.
   */
  predicate construct(Raw::Expr n, Raw::EntryBody b, string kw) {
    inBarrier(n, b) and kw = keyword(n)
  }
}
