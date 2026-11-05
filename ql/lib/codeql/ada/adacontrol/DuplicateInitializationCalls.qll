/**
 * AdaControl rule `Duplicate_Initialization_Calls`: initialization procedures must not
 * be called twice in identical conditions (`docs/adacontrol.md`).
 *
 * A procedure fits one of two patterns (`pattern`): `in` when all its parameters are
 * of mode `in` (the actuals of each call must be static, and no two calls may pass the
 * same values), `out` when it has exactly one `out` parameter and no `in out` one (no
 * two calls may pass the same variable for it).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.adacontrol.Assignments
private import codeql.ada.adacontrol.SimplifiableStatements
private import codeql.ada.adacontrol.Settings

module DuplicateInitializationCalls {
  /**
   * Holds if `s` is an initialization procedure: one named by a row of the data
   * extension `initializationProcedure` (`configured` = true), or, when there is no row,
   * a procedure of the source named `Init` or `Initialize` (`configured` = false).
   */
  predicate isInitializationProcedure(Subprogram s, boolean configured) {
    exists(string name | initializationProcedure(name) and s.hasQualifiedName(name)) and
    configured = true
    or
    not initializationProcedure(_) and
    s.fromSource() and
    s.isProcedure() and
    s.getName().toLowerCase() = ["init", "initialize"] and
    configured = false
  }

  /**
   * Gets the pattern procedure `s` fits: `in` when all its parameters are of mode
   * `in`, `out` when it has exactly one `out` parameter and no `in out` one.
   */
  string pattern(Subprogram s) {
    s.isProcedure() and
    (
      forall(Parameter p | p = s.getAParameter() | p.getMode() = "in") and result = "in"
      or
      strictcount(Parameter p | p = s.getAParameter() and p.getMode() = "out") = 1 and
      not exists(Parameter p | p = s.getAParameter() and p.getMode() = "in out") and
      result = "out"
    )
  }

  /** Gets the `out` parameter of procedure `s`, of pattern `out`. */
  Parameter outParameter(Subprogram s) {
    pattern(s) = "out" and result = s.getAParameter() and result.getMode() = "out"
  }

  /**
   * Gets a key for the static value of `e`: a numeric, character or string literal
   * (possibly negated, parenthesized or qualified), or a name of an enumeration
   * literal, a named number or a constant. No result for anything else.
   */
  string staticKey(Raw::Expr e) {
    exists(Raw::Expr u | u = SimplifiableStatements::unparen(e) |
      result = "i" + u.(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
      or
      result = "r" + u.(Raw::RealLiteral).getValue().replaceAll("_", "")
      or
      result = "c" + u.(Raw::CharLiteral).getValue()
      or
      result = "s" + u.(Raw::StringLiteral).getValue()
      or
      result = "-" + staticKey(u.(Raw::UnOp).getExpr()) and u.(Raw::UnOp).getOp() instanceof Raw::OpMinus
      or
      result = staticKey(u.(Raw::QualExpr).getSuffix())
      or
      exists(Raw::BasicDecl d, Raw::Name n | n = u and d = n.getReferencedDecl() |
        (
          d instanceof Raw::EnumLiteralDecl or
          d instanceof Raw::NumberDecl or
          d.(Raw::ObjectDecl).getHasConstant() instanceof Raw::ConstantPresent
        ) and
        result = "n" + d.getQualifiedName().toLowerCase() + "/" +
            n.getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase()
      )
    )
  }

  /**
   * Gets the expression call `c` passes for parameter `p` of its target: the actual, or
   * the parameter's default when there is none.
   */
  Raw::Expr actualOrDefault(Call c, Parameter p) {
    p = c.getTarget().getAParameter() and
    (
      result = c.getArgumentFor(p)
      or
      not exists(c.getArgumentFor(p)) and result = p.getDefaultExpr()
    )
  }

  /** Holds if call `c` passes, for parameter `p`, a value that is not static. */
  predicate nonStaticActual(Call c, Parameter p) {
    exists(Raw::Expr e | e = actualOrDefault(c, p) | not exists(staticKey(e)))
  }

  /**
   * Gets the values call `c` (of a procedure of pattern `in`) passes, as one key,
   * when they are all static.
   */
  string callKey(Call c) {
    pattern(c.getTarget()) = "in" and
    not nonStaticActual(c, _) and
    result =
      concat(Parameter p, int i |
        p = c.getTarget().getParameter(i)
      |
        staticKey(actualOrDefault(c, p)), "," order by i
      )
  }

  /** Holds if `a` comes before `b` in the source: by file, then line, then column. */
  predicate precedes(Raw::AdaNode a, Raw::AdaNode b) {
    exists(string fa, int la, int ca, string fb, int lb, int cb |
      a.getLocation().hasLocationInfo(fa, la, ca, _, _) and
      b.getLocation().hasLocationInfo(fb, lb, cb, _, _)
    |
      fa < fb or fa = fb and (la < lb or la = lb and ca < cb)
    )
  }

  /**
   * Holds if `second` duplicates `first`, the first call in the source to do the same:
   * for pattern `in`, a call with the same static values; for pattern `out`, a call
   * with the same variable for the `out` parameter.
   */
  predicate duplicate(Call first, Call second) {
    duplicateOf(first, second) and
    not exists(Call earlier | duplicateOf(earlier, first))
  }

  /** Holds if `b` does the same as `a`, which comes before it. */
  private predicate duplicateOf(Call a, Call b) {
    a.getTarget() = b.getTarget() and
    precedes(a, b) and
    (
      callKey(a) = callKey(b)
      or
      exists(Parameter p | p = outParameter(a.getTarget()) |
        Assignments::isStaticTarget(a.getArgumentFor(p)) and
        Assignments::sameName(a.getArgumentFor(p), b.getArgumentFor(p))
      )
    )
  }
}
