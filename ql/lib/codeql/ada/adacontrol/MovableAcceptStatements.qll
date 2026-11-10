/**
 * AdaControl rule `Movable_Accept_Statements`: statements of an `accept` body that do
 * not need the rendezvous, and could follow it, so that the caller waits less
 * (`docs/adacontrol.md`).
 *
 * A statement of an `accept` body is *not movable* (`nonMovable`) when it, or a
 * statement in it, synchronizes (`delay`, `accept`, `select`, `requeue`, `abort`, an
 * entry call), references a parameter of the `accept`, or leaves the `accept` body
 * (`return`, `raise`, `goto`, an `exit` of a loop around it): moving it would change
 * what the rendezvous does.
 */

private import codeql.ada.ast.internal.Raw

module MovableAcceptStatements {
  /** Gets the `i`th statement (0-based) of the body of `accept` statement `a`. Pragmas are not statements. */
  Raw::AdaNode bodyStmt(Raw::AcceptStmtWithStmts a, int i) {
    result = a.getStmts().getStmts().getChild(i) and not result instanceof Raw::PragmaNode
  }

  /** Holds if `n` is `s` or in it. */
  private predicate inStmt(Raw::AdaNode n, Raw::AdaNode s) { n.getParent*() = s }

  /** Gets the name of a parameter of `accept` statement `a`, in lower case. */
  private string parameterName(Raw::AcceptStmt a) {
    result =
      any(Raw::ParamSpec p | p.getParent+() = a.getParams())
          .getIds()
          .getChild(_)
          .(Raw::DefiningName)
          .getName()
          .getText()
          .toLowerCase()
  }

  /**
   * Holds if name `n`, in `accept` statement `a`, references a parameter of `a`: the
   * `accept`'s own, or the entry declaration's of the same name, which a reference may
   * resolve to instead. An identifier that does not resolve (a parameter of a type the
   * extractor does not know) counts when it is spelled like a parameter and is not a
   * selector.
   */
  predicate referencesParameter(Raw::Name n, Raw::AcceptStmt a) {
    n.getParent+() = a and
    (
      n.getReferencedDecl().getParent+() = a.getParams()
      or
      n.getReferencedDecl().getParent+() instanceof Raw::EntryDecl and
      n.(Raw::Identifier).getText().toLowerCase() = parameterName(a)
      or
      not exists(n.getReferencedDecl()) and
      n.(Raw::Identifier).getText().toLowerCase() = parameterName(a) and
      not n = any(Raw::DottedName d).getSuffix() and
      not n = any(Raw::ParamAssoc pa).getDesignator()
    )
  }

  /** Holds if `n` synchronizes: a `delay`, `accept`, `select`, `requeue`, `abort`, or an entry call. */
  private predicate synchronizes(Raw::AdaNode n) {
    n instanceof Raw::DelayStmt or
    n instanceof Raw::AcceptStmt or
    n instanceof Raw::SelectStmt or
    n instanceof Raw::RequeueStmt or
    n instanceof Raw::AbortStmt or
    n.(Raw::Name).getReferencedDecl() instanceof Raw::EntryDecl
  }

  /** Holds if `n`, in statement `s`, leaves `s`: `return`, `raise`, `goto`, or an `exit` of a loop around `s`. */
  private predicate leaves(Raw::AdaNode n, Raw::AdaNode s) {
    inStmt(n, s) and
    (
      n instanceof Raw::ReturnStmt or
      n instanceof Raw::RaiseStmt or
      n instanceof Raw::GotoStmt or
      n instanceof Raw::ExitStmt and
      not exists(Raw::BaseLoopStmt l | n.getParent+() = l and inStmt(l, s))
    )
  }

  /**
   * Holds if statement `s` of the body of `a` is not movable, for `reason`:
   * `synchronization`, `parameter` or `jump`.
   */
  predicate nonMovable(Raw::AdaNode s, Raw::AcceptStmtWithStmts a, string reason) {
    s = bodyStmt(a, _) and
    (
      exists(Raw::AdaNode n | inStmt(n, s) and synchronizes(n)) and reason = "synchronization"
      or
      exists(Raw::Name n | inStmt(n, s) and referencesParameter(n, a)) and reason = "parameter"
      or
      leaves(_, s) and reason = "jump"
    )
  }

  /**
   * `certain`: statement `s` of the body of `a` comes after the last statement that is
   * not movable. `null` statements are not reported.
   */
  predicate certain(Raw::AdaNode s, Raw::AcceptStmtWithStmts a) {
    exists(int i |
      s = bodyStmt(a, i) and
      not s instanceof Raw::NullStmt and
      not exists(int j | j >= i and nonMovable(bodyStmt(a, j), a, _))
    )
  }

  /**
   * Holds if `v`, a declaration referenced in the body of `a`, depends on a parameter
   * of `a`: some statement of the body references both, or references both it and a
   * declaration that does (a simple, symmetric data flow).
   */
  private predicate dependsOnParameter(Raw::BasicDecl v, Raw::AcceptStmtWithStmts a) {
    exists(Raw::AdaNode s, Raw::Name n |
      s = bodyStmt(a, _) and
      inStmt(n, s) and
      v = n.getReferencedDecl() and
      v instanceof Raw::ObjectDecl and
      (
        nonMovable(s, a, "parameter")
        or
        exists(Raw::Name m, Raw::BasicDecl w |
          inStmt(m, s) and w = m.getReferencedDecl() and w != v and dependsOnParameter(w, a)
        )
      )
    )
  }

  /**
   * `possible`: statement `s` of the body of `a` is movable and references no variable
   * that depends on a parameter (`certain` statements included). `null` statements are
   * not reported.
   */
  predicate possible(Raw::AdaNode s, Raw::AcceptStmtWithStmts a) {
    s = bodyStmt(a, _) and
    not s instanceof Raw::NullStmt and
    not nonMovable(s, a, _) and
    not exists(Raw::Name n | inStmt(n, s) and dependsOnParameter(n.getReferencedDecl(), a))
  }
}
