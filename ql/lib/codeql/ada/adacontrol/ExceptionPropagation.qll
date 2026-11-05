/**
 * AdaControl rule `Exception_Propagation`: program units that must not propagate
 * exceptions (exported subprograms, call-backs, tasks), declarations that can raise,
 * and local exceptions that can escape their scope (`docs/adacontrol.md`).
 *
 * A subprogram or task body is *non-propagating* at level `level` (0 to 3) when it has
 * a `when others` handler, no handler raises or re-raises (a `raise` statement or
 * expression, or a call to `Ada.Exceptions.Raise_Exception` or `Reraise_Occurrence`),
 * and no declaration of its declarative part propagates at that level
 * (`declarationPropagates`). A null procedure never propagates.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Places
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.SilentExceptions

module ExceptionPropagation {
  /** Gets the handled statements of body or block `b`. */
  Raw::HandledStmts handledStmts(Raw::AdaNode b) {
    result = b.(Raw::SubpBody).getStmts() or
    result = b.(Raw::TaskBody).getStmts() or
    result = b.(Raw::EntryBody).getStmts() or
    result = b.(Raw::DeclBlock).getStmts() or
    result = b.(Raw::BeginBlock).getStmts()
  }

  /** Gets an exception handler of body or block `b`. */
  Raw::ExceptionHandler handler(Raw::AdaNode b) {
    result = handledStmts(b).getExceptions().getChild(_)
  }

  /** Gets the declarative part of body or block `b`. */
  Raw::DeclarativePart declarations(Raw::AdaNode b) {
    result = b.(Raw::SubpBody).getDecls() or
    result = b.(Raw::TaskBody).getDecls() or
    result = b.(Raw::EntryBody).getDecls() or
    result = b.(Raw::DeclBlock).getDecls()
  }

  /** Holds if `n` calls `Ada.Exceptions.Raise_Exception` (`reraise` false) or `Reraise_Occurrence` (true). */
  private predicate callsRaise(Raw::AdaNode n, boolean reraise) {
    n.(Call).getTarget().hasQualifiedName("Ada.Exceptions.Raise_Exception") and reraise = false
    or
    n.(Call).getTarget().hasQualifiedName("Ada.Exceptions.Reraise_Occurrence") and reraise = true
  }

  /** Holds if `n` raises or re-raises: a `raise` statement or expression, or a call that raises. */
  predicate isRaise(Raw::AdaNode n) {
    n instanceof Raw::RaiseStmt or n instanceof Raw::RaiseExpr or callsRaise(n, _)
  }

  /** Holds if handler `h` raises or re-raises an exception somewhere in its statements. */
  predicate handlerRaises(Raw::ExceptionHandler h) {
    exists(Raw::AdaNode n | n.getParent+() = h.getStmts() and isRaise(n))
  }

  /* --- declarations ---------------------------------------------------------- */

  /**
   * Holds if `n` is part of declaration `d` that is evaluated when `d` is elaborated:
   * not inside a subprogram spec (default parameters), a body, a generic, a task or
   * protected type, or a record component's default.
   */
  private predicate elaborated(Raw::BasicDecl d, Raw::AdaNode n) {
    n.getParent+() = d and
    not exists(Raw::AdaNode p | n.getParent+() = p and p.getParent*() = d |
      p instanceof Raw::BaseSubpSpec or
      p instanceof Raw::BodyNode or
      p instanceof Raw::GenericDecl or
      p instanceof Raw::TaskTypeDecl or
      p instanceof Raw::ProtectedTypeDecl or
      p instanceof Raw::SingleProtectedDecl or
      p instanceof Raw::ComponentDecl
    )
  }

  /** Holds if `d` is a named number or a scalar type declaration, which the language requires to be static. */
  private predicate isStaticByLanguage(Raw::BasicDecl d) {
    d instanceof Raw::NumberDecl
    or
    d instanceof Raw::TypeDecl and
    TypeCategories::declaredCategory(d) = ["()", "delta", "digits", "mod", "range"]
  }

  /** Holds if `n` calls a function: a resolved function call, an operator, or an attribute with arguments. */
  predicate isFunctionCall(Raw::AdaNode n) {
    n.(Call).getTarget().isFunction()
    or
    n instanceof Raw::BinOp and not n.(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot
    or
    n instanceof Raw::UnOp
    or
    exists(n.(Raw::AttributeRef).getArgs().getChild(_))
  }

  /** Holds if identifier `n` uses a variable (not a constant) or a parameter. */
  predicate isVariableUse(Raw::Identifier n) {
    exists(Variable v | n = v.getAnAccess() and not v.isConstant())
    or
    n = any(Parameter p).getAnAccess()
  }

  /**
   * Holds if declaration `d` can propagate an exception at level `level`, AdaControl's
   * `<level>`: at 1 (and above), when it calls a function (operators included), except
   * in a named number or scalar type declaration; at 2, also when it uses a variable;
   * at 3, also when it declares an object. At level 0 no declaration propagates.
   */
  predicate declarationPropagates(Raw::BasicDecl d, int level) {
    level in [1 .. 3] and
    exists(Places::declarativePart(d)) and
    (
      exists(Raw::AdaNode n | elaborated(d, n) and isFunctionCall(n)) and
      not isStaticByLanguage(d)
      or
      level >= 2 and exists(Raw::Identifier n | elaborated(d, n) and isVariableUse(n))
      or
      level = 3 and d instanceof Raw::ObjectDecl
    )
  }

  /* --- units ----------------------------------------------------------------- */

  /**
   * Holds if body `b` (a subprogram or task body) cannot propagate an exception at
   * level `level`, by the test above.
   */
  bindingset[level]
  predicate isNonPropagating(Raw::AdaNode b, int level) {
    b instanceof Raw::NullSubpDecl
    or
    (b instanceof Raw::BaseSubpBody or b instanceof Raw::TaskBody) and
    SilentExceptions::handlesOthers(handler(b)) and
    not handlerRaises(handler(b)) and
    not exists(Raw::BasicDecl d | d = declarations(b).getDecls().getChild(_) |
      declarationPropagates(d, level)
    )
  }

  /** Holds if subprogram or task body `b` can propagate an exception at level `level`. */
  bindingset[level]
  predicate canPropagate(Raw::AdaNode b, int level) {
    (b instanceof Raw::BaseSubpBody and not b instanceof Raw::SubpRenamingDecl or b instanceof Raw::TaskBody) and
    not isNonPropagating(b, level)
  }

  /* --- interface ------------------------------------------------------------- */

  /** Gets the text of name `e`, lower-cased: a convention (`C`) or an aspect name. */
  private string nameText(Raw::Expr e) { result = e.(Raw::Name).getText().toLowerCase() }

  /** Holds if pragma `p` (`Export` or `Interface`) applies to `d`, with convention `convention`. */
  private predicate exportPragma(Raw::PragmaNode p, Raw::BasicDecl d, string convention) {
    p.getId().getValue().toLowerCase() = ["export", "interface"] and
    exists(Raw::PragmaArgumentAssoc conv, Raw::PragmaArgumentAssoc entity |
      (
        conv = p.getArgs().getChild(0) and not exists(conv.getName())
        or
        conv = p.getArgs().getChild(_) and nameText(conv.getName()) = "convention"
      ) and
      (
        entity = p.getArgs().getChild(1) and not exists(entity.getName())
        or
        entity = p.getArgs().getChild(_) and nameText(entity.getName()) = "entity"
      ) and
      convention = nameText(conv.getExpr()) and
      d = entity.getExpr().(Raw::Name).getReferencedDecl()
    )
  }

  /** Gets the aspect named `name` of declaration `d`. */
  private Raw::AspectAssoc aspect(Raw::BasicDecl d, string name) {
    result = d.getAspects().getAspectAssocs().getChild(_) and nameText(result.getId()) = name
  }

  /**
   * Holds if subprogram `s` is exported to (or interfaced with) another language with
   * convention `convention` (lower case): by pragma `Export` or `Interface`, or by the
   * aspect `Export` with a `Convention`.
   */
  predicate isExported(Subprogram s, string convention) {
    exportPragma(_, s.getADeclaration(), convention)
    or
    exists(Raw::BasicDecl d | d = s.getADeclaration() |
      exists(Raw::AspectAssoc e | e = aspect(d, "export") |
        not nameText(e.getExpr()) = "false"
      ) and
      convention = nameText(aspect(s.getADeclaration(), "convention").getExpr())
    )
  }

  /* --- parameter ------------------------------------------------------------- */

  /**
   * Holds if call `c` passes subprogram `s`, as `'Access`, `'Unchecked_Access`,
   * `'Unrestricted_Access` or `'Address`, for its parameter `p` (subrule `parameter`).
   * Calls through an access type, and generic formal subprograms, are not followed.
   */
  predicate passesSubprogram(Call c, Parameter p, Subprogram s) {
    exists(Raw::AttributeRef a |
      a = c.getArgumentFor(p) and
      a.getAttribute().getValue().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access", "address"] and
      a.getPrefix().getReferencedDecl() = s.getADeclaration()
    )
  }

  /* --- local_exception ------------------------------------------------------- */

  /** Holds if `e` (one name of an exception declaration) is declared in body or block `b`. */
  predicate isLocalException(Raw::DefiningName e, Raw::AdaNode b) {
    exists(Raw::ExceptionDecl d |
      e = d.getIds().getChild(_) and
      not exists(d.getRenames()) and
      d = declarations(b).getDecls().getChild(_)
    )
  }

  /** Holds if name `n` denotes exception `e`. */
  private predicate denotes(Raw::Name n, Raw::DefiningName e) {
    n.getReferencedDecl().getADefiningName() = e and
    n.getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase() =
      e.getName().getText().toLowerCase()
  }

  /** Holds if handler `h` names exception `e` among its choices. */
  private predicate handlesByName(Raw::ExceptionHandler h, Raw::DefiningName e) {
    denotes(h.getHandledExceptions().getChild(_), e)
  }

  /**
   * Gets the handler of `b` that catches exception `e`: the one naming it, else the
   * `when others` one.
   */
  Raw::ExceptionHandler catcher(Raw::AdaNode b, Raw::DefiningName e) {
    isLocalException(e, b) and
    result = handler(b) and
    (
      handlesByName(result, e)
      or
      not handlesByName(handler(b), e) and SilentExceptions::handlesOthers(result)
    )
  }

  /** Holds if `n` raises exception `e` explicitly: `raise E`, or `Raise_Exception (E'Identity, ...)`. */
  predicate raisesExplicitly(Raw::AdaNode n, Raw::DefiningName e) {
    denotes(n.(Raw::RaiseStmt).getExceptionName(), e)
    or
    denotes(n.(Raw::RaiseExpr).getExceptionName(), e)
    or
    callsRaise(n, false) and
    denotes(n.(Call).getArgument(0).(Raw::AttributeRef).getPrefix(), e)
  }

  /** Holds if `n`, in a handler that catches `e`, re-raises the exception it handles: `raise;` or `Reraise_Occurrence`. */
  private predicate reraises(Raw::AdaNode n) {
    n instanceof Raw::RaiseStmt and not exists(n.(Raw::RaiseStmt).getExceptionName())
    or
    callsRaise(n, true)
  }

  /**
   * Holds if local exception `e`, declared in body or block `b`, can escape it
   * (subrule `local_exception`), at `site`: the declaration, when no handler of `b`
   * catches it (`reason` = `unhandled`); a re-raise in the handler that catches it
   * (`reraised`); an explicit raise of `e` in any handler of `b` (`raised`).
   */
  predicate localExceptionEscapes(Raw::DefiningName e, Raw::AdaNode b, Raw::AdaNode site, string reason) {
    isLocalException(e, b) and
    (
      not exists(catcher(b, e)) and site = e and reason = "unhandled"
      or
      site.getParent+() = catcher(b, e).getStmts() and reraises(site) and reason = "reraised"
      or
      site.getParent+() = handler(b).getStmts() and raisesExplicitly(site, e) and reason = "raised"
    )
  }
}
